# JacPlanner implementation plan

Build a local, single-user coursework planner for Kaden Gruizenga using Jac 0.37.23. No AI provider is required. Validate the mobile app on an iPhone simulator. Leave the UMID as a README placeholder.

## Features

- Tasks have a title, course, due date, low/medium/high priority, estimated minutes, planned date, notes, and completion status.
- The web dashboard creates and edits tasks, filters by course/status, and shows a chosen day's plan and estimated workload.
- The native mobile app shows a daily plan, adds tasks, and completes or reopens tasks.
- The CLI adds, lists, schedules, completes, and reopens tasks against the same server.
- Data survives server restarts. Dates are stored as YYYY-MM-DD and displayed in U.S. format.

## Ownership

- Backend subagent: core/models.jac, core/planner.jac, backend tests.
- Web subagent: web/ source and styles.
- Mobile subagent: mobile/ source and native verification.
- Main agent: jac.toml, CLI, README, integration checks, final verification.

## Shared contract

`core/models.jac` defines these public wire objects:

- TaskView: taskId: str, title: str, course: str, dueDate: str, priority: str, estimateMinutes: int, plannedDate: str, notes: str, completed: bool.
- TaskList: tasks: list[TaskView].
- TaskResult: ok: bool, error: str, task: TaskView | None.

`core/planner.jac` is the `planner` service entry and exposes public functions:

- ListTasks() -> TaskList
- SaveTask(taskId: str = "", title: str = "", course: str = "", dueDate: str = "", priority: str = "medium", estimateMinutes: int = 30, plannedDate: str = "", notes: str = "") -> TaskResult
- SetCompleted(taskId: str, completed: bool) -> TaskResult
- DeleteTask(taskId: str) -> TaskResult

SaveTask creates when taskId is empty, otherwise replaces editable fields and preserves completion. Blank dates mean unscheduled/no deadline. Server rejects invalid dates, empty titles, unknown priorities, estimates outside 1..1440, and unknown IDs. UI awaits imported service functions and reads typed results. SQLite in the ignored .jac/ directory provides transactional local persistence; JACPLANNER_DB may override its path for isolated tests.

## Acceptance checks

1. Formatting, compiler checks, backend and CLI tests pass.
2. Bare jac run serves web and backend.
3. A web-created task can be listed and updated through CLI and mobile.
4. Restarting the server preserves tasks.
5. Web empty/error states and mobile simulator workflows are exercised.
6. README gives prerequisites, web/mobile/CLI commands, architecture, author, UMID placeholder, and verified limitations.

Commit only our files in logical groups. Do not push, submit to Canvas, or modify the sibling mysite example.

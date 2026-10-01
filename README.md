# JacPlanner

A personal coursework planner built with Jac. Organize assignments by course, set priorities and deadlines, and choose a manageable daily workload. The web dashboard, native mobile app, and terminal commands share one persistent server.

- **Author:** Kaden Gruizenga
- **UMID:** TODO: add before submission
- **Course:** EECS 449, Fall 2026, Extra Credit 1

## Requirements

- Jac **0.37.23**, matching `jac.toml`.
- Bun for JavaScript dependencies.
- `uv` and Python **3.14** for the project environment.
- For iPhone simulator use: macOS, Xcode with an installed iOS simulator runtime, and the native build prerequisites described in [mobile/README.md](mobile/README.md).

No AI API key or account setup is needed. This is a single-user app without authentication. The backend binds to `127.0.0.1`, but Jac 0.37.23 launches its development web proxy on all network interfaces, so the default development session can expose planner data to your local network. Run it on a trusted network and stop it when finished.

## Start the web app and server

On a fresh checkout, run these from the repository root:

```sh
uv venv --seed --python 3.14 .jac/venv
jac install
jac run
```

The environment creation is a one-time step. It avoids an observed Jac 0.37.23 bundled-Python error (`_PyBytes_AsString`) during automatic environment creation on this Mac. No environment activation is needed; Jac uses `.jac/venv` directly. On later launches, run `jac run`.

Open **http://127.0.0.1:8000**. Keep that terminal running while using the web, CLI, or simulator. Stop it with Control-C when finished. Jac manages a persistent Postgres store for the project automatically. Task data survives server restarts and is separate from the source files in Git.

The web calendar shows scheduled work as time blocks. Use the task tray to find unscheduled work, choose a day and start time, and filter by course. Drag the bottom edge of a calendar block to change its duration. Resizing snaps to 15-minute steps and stops at midnight; the task editor still accepts exact minutes. Short blocks show only their title when there is not enough room for the time.

The Tasks view provides compact, searchable rows for editing, completing, reopening, and deleting work. Unfinished tasks with deadlines before today carry an Overdue label. A past scheduled work session alone does not make a task overdue. Each task has a course, optional deadline, priority, estimated minutes, optional plan date and start time, and notes.

Start times use local wall-clock time. Estimated minutes determine the block's length. A time requires a plan date, and a block cannot extend past midnight. Tasks with a date but no time remain available as untimed work for that day. Deadlines and planned work are separate: choosing a work session does not change the deadline.

## CLI

Run these from a second terminal in the repository root while the server is running. Dates in commands use `YYYY-MM-DD`; `today` is also accepted for plan dates.

```sh
jac run cli -- add "Finish project proposal" --course "EECS 449" --priority high --minutes 60 --due 2026-10-05 --day today --time 10:00
jac run cli -- list --day today --status open
jac run cli -- list --course "EECS 449"
jac run cli -- --json list
jac run cli -- schedule TASK_ID 2026-10-01 --time 14:00
jac run cli -- schedule TASK_ID none
jac run cli -- complete TASK_ID
jac run cli -- reopen TASK_ID
```

Replace `TASK_ID` with an ID printed by `list`, or a unique prefix. Ambiguous prefixes are rejected. Put global options before the command:

```sh
jac run cli -- --server http://127.0.0.1:8000 --json list
jac run cli -- --help
```

The CLI exits with code 0 on success, 1 for an unavailable service, and 2 for invalid input. It never opens a separate task database.

## Mobile

The mobile app uses Jac's native UI primitives and an Expo/React Native project generated locally by Jac. See [the mobile instructions](mobile/README.md) for simulator startup and controls. It connects to the same running planner service as the browser and CLI.

## How it fits together

| Component | Source | Responsibility |
| --- | --- | --- |
| Server | `core/planner.jac` | Validates changes and persists task nodes attached to the Jac root |
| Wire models | `core/models.jac` | Typed task and operation results shared across app boundaries |
| Web | `web/main.jac` | Weekly calendar, scheduling, and task management |
| Mobile | `mobile/main.jac` | Native daily timeline, task entry, scheduling, and completion |
| CLI | `cli/main.jac` | Terminal task management through the service bridge |

`jac.toml` declares four apps and chooses `web` as the default. The planner service exposes `ListTasks`, `SaveTask`, `ScheduleTask`, `SetCompleted`, and `DeleteTask`. Clients await typed Jac bridge calls. They receive task views rather than direct access to persistent nodes. The web server mounts the planner at `/api/planner`.

The focus is a consistent workflow across all three interfaces: capture work, estimate it, choose a day, and finish it. There is no sample task data inserted automatically.

## Development checks

```sh
jac check
jac check core web mobile cli --lint
jac test
jac build --as client web
bun test web
```

Backend tests use temporary isolated stores and check CRUD, validation, and persistence after reopening the server. CLI tests cover calendar validation and safe task-ID selection. Web regression tests exercise compiler-emitted calendar helpers, resize bounds, overdue rules, and editor focus behavior, so build the web client before running them. They cover short and overlapping blocks, midnight bounds, date navigation across daylight saving, leap day, and New Year, and keyboard focus during editing. Generated dependencies, simulator projects, builds, and local data stay out of Git.

## Verification and limitations

Verified on 09/30/2026 with Jac 0.37.23:

- All four apps pass compiler checks. Source lint reports no errors; the save API has a parameter-count warning.
- Eight backend and CLI tests pass, including time validation, midnight limits, preserving start times during older-client edits, and persistence after restart.
- Fresh-checkout setup and server restart persistence were verified before the calendar redesign. The redesign uses the same dependencies and startup commands.
- The redesigned web calendar was checked for task creation, time editing, overlapping blocks, drag scheduling, untimed weekend tasks, search/course/status filters, completion/reopening, and phone-width layout.
- On 10/01/2026, browser checks verified bottom-edge drag resizing and persistence after reload, keyboard resizing and midnight limits, canceled gestures, failed-save recovery, overdue exclusions, the delete menu, and 390px task rows.
- Additional web QA covered form limits, literal HTML and Unicode, New Year dates, midnight scheduling, canceled edits and deletion, 390px layout, keyboard navigation, delayed saves, and simulated connection failures. Calendar and editor regressions run with `bun test web` after building the client.
- Web-created time blocks can be read and rescheduled through the CLI and mobile interface. Mobile time editing, invalid-time feedback, completion, and reopening were exercised through its browser target against the same server.
- The redesigned native iOS timeline launches and reads shared tasks on an iOS 26.5 simulator. The unsigned native build succeeds. Native taps were not automated; the generated Expo template still requires the documented iOS 26.5 workaround for launch, and unsigned builds may show SecureStore entitlement warnings.

The planner needs the server running and has no offline mode or account isolation. Before submitting, replace the UMID placeholder and try the native controls in Device Hub.

## References

- [Jac documentation](https://jaclang.org/docs/latest)
- [Build an AI Day Planner tutorial](https://jaclang.org/docs/v0.37/tutorials/first-app/build-ai-day-planner), adapted for coursework without AI
- The `jac create --awesome` example, used to understand the multi-app structure

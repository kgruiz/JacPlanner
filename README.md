# JacPlanner

JacPlanner is a coursework planner built with Jac for keeping track of assignments and deciding when to work on them. You can plan your week on the web, check your tasks on an iPhone, or add an assignment from the terminal. They all connect to the same server, so you can switch between them without keeping separate task lists.

- **Author:** Kaden Gruizenga
- **UMID:** 07961011
- **Course:** EECS 449, Fall 2026, Extra Credit 1

## Requirements

- Jac **0.37.23**, matching `jac.toml`.
- Bun for JavaScript dependencies.
- `uv` and Python **3.14** for the project environment.
- For iPhone simulator use: macOS, Xcode with an installed iOS simulator runtime, and the native build prerequisites described in [mobile/README.md](mobile/README.md).

You don't need an account or an AI API key to use the planner. It's intended for one person running it locally. Although the backend listens on `127.0.0.1`, Jac 0.37.23 exposes its development web proxy to the local network, so run it on a network you trust and stop the server when you're done.

## Start the web app and server

On a fresh checkout, run these from the repository root:

```sh
uv venv --seed --python 3.14 .jac/venv
jac install
jac run
```

The first command works around a `_PyBytes_AsString` error encountered during Jac's automatic setup on macOS. You only need to create the environment once, and you don't need to activate it because Jac uses `.jac/venv` directly. After that, `jac run` is enough to start the app.

Once the server starts, open **http://127.0.0.1:8000** and leave the terminal running while you use the app. The CLI and mobile app need it too. Press Control-C when you're finished; your tasks are saved in Jac's Postgres store and will still be there the next time you start it.

## Using the planner

The app starts with an empty task list. Add an assignment with its course, deadline, priority, and an estimate of how long it'll take. You can also add notes or leave the deadline blank if there isn't one.

When you're ready to make time for a task, drag it from the unscheduled tray onto the calendar. You can move the block to another day or time, and drag its bottom edge to give yourself more or less time. Both actions snap to 15-minute steps, while the task editor lets you enter an exact duration. The time updates as you drag, and the new schedule is saved when you let go.

A task's deadline is separate from its scheduled work time. An assignment could be due Friday even though you've set aside Wednesday afternoon to work on it, so moving that study block won't change the deadline. Overdue assignments are marked in red, and course colors help you see how the week's work is spread out.

If you'd rather work from a list, the Tasks tab lets you search, edit, complete, reopen, or delete tasks. You can filter by course in either view.

All scheduled times are local. A block needs a date and can't extend past midnight, but you can leave its start time blank to keep it on a day's plan without reserving a specific time. Short blocks hide details that won't fit.

## CLI

With the server still running, open a second terminal in the repository root. These examples show how to add a task, find its ID, and update it. Enter dates as `YYYY-MM-DD`, or use `today` when choosing a planned date.

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

Replace `TASK_ID` with an ID from `list`. You can use just the beginning of the ID as long as it matches only one task. Options such as `--server` and `--json` go before the command:

```sh
jac run cli -- --server http://127.0.0.1:8000 --json list
jac run cli -- --help
```

The CLI uses the running server. It exits with code 0 on success, 1 if the service is unavailable, and 2 for invalid input.

## Mobile

The iPhone app has a daily calendar and a task list, and it connects to the server you've already started. Follow the [mobile setup instructions](mobile/README.md) to build and run it in an iOS 26.5 simulator. Jac generates the Expo/React Native project from the mobile Jac source.

## How it fits together

| Component | Source | Responsibility |
| --- | --- | --- |
| Server | `core/planner.jac` | Validates changes and persists task nodes attached to the Jac root |
| Wire models | `core/models.jac` | Typed task and operation results shared across app boundaries |
| Web | `web/main.jac` | Weekly calendar, scheduling, and task management |
| Mobile | `mobile/main.jac` | Native daily timeline, task entry, scheduling, and completion |
| CLI | `cli/main.jac` | Terminal task management through the service bridge |

The four apps are defined in `jac.toml`, with `web` as the default so that `jac run` starts the browser app and its server. The planner service is available at `/api/planner`, where it handles task storage and validation. Each interface calls the same `ListTasks`, `SaveTask`, `ScheduleTask`, `SetCompleted`, and `DeleteTask` functions through Jac, so the rules for saving and scheduling tasks stay the same across the app.

## Development checks

```sh
jac check
jac check core web mobile cli --lint
jac test
jac build --as client web
bun test web
```

The backend tests use temporary stores, so they can check task changes and persistence without touching your saved tasks. The CLI tests check dates and task ID matching, while the web tests cover calendar behavior. Since those tests use the compiled web code, run the client build before `bun test web`.

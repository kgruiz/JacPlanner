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

No AI API key or account setup is needed. This is a single-user app intended to run locally on your Mac. The server binds to `127.0.0.1` and exposes the planner without authentication.

## Start the web app and server

On a fresh checkout, run these from the repository root:

```sh
uv venv --seed --python 3.14 .jac/venv
jac install
jac run
```

The environment creation is a one-time step. It avoids an observed Jac 0.37.23 bundled-Python error (`_PyBytes_AsString`) during automatic environment creation on this Mac. No environment activation is needed; Jac uses `.jac/venv` directly. On later launches, run `jac run`.

Open **http://127.0.0.1:8000**. Keep that terminal running while using the web, CLI, or simulator. Stop it with Control-C when finished. Jac manages a persistent Postgres store for the project automatically. Task data survives server restarts and is separate from the source files in Git.

Use the dashboard to add and edit tasks, filter coursework, choose a plan date, and complete or reopen work. Each task has a course, optional deadline, priority, estimated minutes, optional plan date, and notes.

## CLI

Run these from a second terminal in the repository root while the server is running. Dates in commands use `YYYY-MM-DD`; `today` is also accepted for plan dates.

```sh
jac run cli -- add "Finish project proposal" --course "EECS 449" --priority high --minutes 60 --due 2026-10-05 --day today
jac run cli -- list --day today --status open
jac run cli -- list --course "EECS 449"
jac run cli -- --json list
jac run cli -- schedule TASK_ID 2026-10-01
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
| Web | `web/main.jac` | Coursework dashboard and daily planning |
| Mobile | `mobile/main.jac` | Native daily plan, quick task entry, completion and reopening |
| CLI | `cli/main.jac` | Terminal task management through the service bridge |

`jac.toml` declares four apps and chooses `web` as the default. The planner service exposes `ListTasks`, `SaveTask`, `SetCompleted`, and `DeleteTask`. Clients await typed Jac bridge calls. They receive task views rather than direct access to persistent nodes. The web server mounts the planner at `/api/planner`.

The focus is a consistent workflow across all three interfaces: capture work, estimate it, choose a day, and finish it. There is no sample task data inserted automatically.

## Development checks

```sh
jac check
jac check core web mobile cli --lint
jac test
```

Backend tests use temporary isolated stores and check CRUD, validation, and persistence after reopening the server. CLI tests cover calendar validation and safe task-ID selection. Generated dependencies, simulator projects, builds, and local data stay out of Git.

## Verification and limitations

Verified on 09/30/2026 with Jac 0.37.23:

- All four apps pass compiler checks. Source lint reports no errors; the eight-field save API has a parameter-count warning.
- Six backend and CLI tests pass.
- A fresh local checkout installs with the commands above, serves the dashboard, and preserves a task across a server restart.
- Browser CRUD, course/status filtering, daily workload, date changes, validation messages, phone-width layout, and recovery after a server outage were exercised.
- Browser-created tasks can be changed through the CLI and the mobile interface. Mobile add, complete, and reopen workflows were exercised through its browser target against the same server.
- The native iOS app builds, launches, and reads the shared task on an iOS 26.5 simulator. Native taps were not automated because Device Hub control timed out. The generated Expo template failed to launch on iOS 27; use iOS 26.5 with the documented build workaround.

The planner needs the server running and has no offline mode or account isolation. Before submitting, replace the UMID placeholder and try the native controls in Device Hub.

## References

- [Jac documentation](https://jaclang.org/docs/latest)
- [Build an AI Day Planner tutorial](https://jaclang.org/docs/v0.37/tutorials/first-app/build-ai-day-planner), adapted for coursework without AI
- The `jac create --awesome` example, used to understand the multi-app structure

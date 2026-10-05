import argparse;
import asyncio;
import datetime;
import json;
import sys;
import from jaclang.server { sv_client }
import from jaclang.server.bridge { BridgeError }
import from core.models { TaskView, TaskList, TaskResult }
import from core.planner { ListTasks, SaveTask, ScheduleTask, SetCompleted }

def BuildParser -> argparse.ArgumentParser {
    parser = argparse.ArgumentParser(
        prog="jac run cli --",
        description="Manage coursework in the running JacPlanner server."
    );
    parser.add_argument(
        "--server",
        `default="http://127.0.0.1:8000",
        help="Web server URL (default: http://127.0.0.1:8000)"
    );
    parser.add_argument(
        "--json",
        action="store_true",
        dest="asJson",
        help="Output JSON instead of readable text"
    );
    commands = parser.add_subparsers(dest="command", required=True);
    add = commands.add_parser("add", help="Add a coursework task");
    add.add_argument("title");
    add.add_argument("--course", `default="");
    add.add_argument("--due", `default="", help="Deadline as YYYY-MM-DD");
    add.add_argument(
        "--priority", choices=["low", "medium", "high"], `default="medium"
    );
    add.add_argument("--minutes", `type=int, `default=30);
    add.add_argument("--day", `default="", help="Plan date as YYYY-MM-DD");
    add.add_argument(
        "--time", `default="", help="Block start as HH:MM (requires --day)"
    );
    add.add_argument("--notes", `default="");
    add.add_argument(
        "--repeat", choices=["none", "daily", "weekly"], `default="none",
        help="Repeat after completion daily or weekly"
    );
    listing = commands.add_parser(
        "list", help="List tasks, optionally for one day or course"
    );
    listing.add_argument("--day", `default="", help="YYYY-MM-DD or today");
    listing.add_argument("--course", `default="");
    listing.add_argument("--status", choices=["all", "open", "done"], `default="all");
    schedule = commands.add_parser("schedule", help="Move a task into a daily plan");
    schedule.add_argument("taskId", help="Task ID or unique ID prefix");
    schedule.add_argument("day", help="YYYY-MM-DD, today, or none to unschedule");

    schedule.add_argument("--time", `default="", help="Block start as HH:MM");

    for command in ["complete", "reopen"] {
        action = commands.add_parser(command, help=command.capitalize() + " a task");
        action.add_argument("taskId", help="Task ID or unique ID prefix");
    }

    return parser;
}

def PlanDate(value: str) -> str {
    if value == "today" {
        return datetime.date.today().isoformat();
    }

    if value == "none" {
        return "";
    }

    if value {
        parsed = datetime.date.fromisoformat(value);

        if parsed.isoformat() != value {
            raise ValueError("Use dates in YYYY-MM-DD format.");
        }
    }

    return value;
}

def ResolveTask(tasks: list[TaskView], taskId: str) -> TaskView {
    matches = [
        task
        for task in tasks
        if task.taskId.startswith(taskId)
    ];

    if not taskId or len(matches) != 1 {
        raise ValueError(
            "Task ID must match exactly one task. Run list to find its full ID."
        );
    }

    return matches[0];
}

def DisplayTasks(tasks: list[TaskView], asJson: bool) {
    if asJson {
        print(json.dumps([TaskData(task) for task in tasks], indent=2));

        return;
    }

    if not tasks {
        print("No tasks match this view.");

        return;
    }

    for task in tasks {
        status = "done" if task.completed else "open";
        course = task.course or "No course";
        day = datetime.date.fromisoformat(task.plannedDate).strftime("%m/%d/%Y")
            if task.plannedDate
            else "Unscheduled";
        if task.plannedTime {
            day += " at "
                + datetime.datetime.strptime(task.plannedTime, "%H:%M").strftime(
                    "%I:%M %p"
                );
        }
        due = datetime.date.fromisoformat(task.dueDate).strftime("%m/%d/%Y")
            if task.dueDate
            else "None";
        print(f"[{status}] {task.title} ({course})");
        print(
            f"  {task.priority} priority | {task.estimateMinutes} min | Plan: {day} | Due: {due} | Repeat: {task.recurrence}"
        );
        print(f"  ID: {task.taskId}");
    }
}

def TaskData(task: TaskView) -> dict[str, any] {
    return {
        "taskId": task.taskId,
        "title": task.title,
        "course": task.course,
        "dueDate": task.dueDate,
        "priority": task.priority,
        "estimateMinutes": task.estimateMinutes,
        "plannedDate": task.plannedDate,
        "plannedTime": task.plannedTime,
        "notes": task.notes,
        "completed": task.completed,
        "recurrence": task.recurrence
    };
}

async def main(argv: list[str]) -> int {
    args = BuildParser().parse_args(argv);
    sv_client.register("planner", args.server.rstrip("/"), route="/api/planner");

    try {
        if args.command == "add" {
            result = await SaveTask(
                "",
                args.title,
                args.course,
                args.due,
                args.priority,
                args.minutes,
                PlanDate(args.day),
                args.notes,
                args.time,
                args.repeat
            );
        } else {
            listing = await ListTasks();
            if args.command == "list" {
                day = PlanDate(args.day);
                tasks = [
                    task
                    for task in listing.tasks
                    if (not day or task.plannedDate == day)
                        and (
                            not args.course
                            or task.course.casefold() == args.course.casefold()
                        )
                        and (
                            args.status == "all"
                            or task.completed == (args.status == "done")
                        )
                ];
                DisplayTasks(tasks, args.asJson);

                return 0;
            }
            task = ResolveTask(listing.tasks, args.taskId);
            if args.command == "schedule" {
                result = await ScheduleTask(task.taskId, PlanDate(args.day), args.time);
            } else {
                result = await SetCompleted(task.taskId, args.command == "complete");
            }
        }

        if not result.ok {
            raise ValueError(result.error);
        }

        if result.task is not None {
            DisplayTasks([result.task], args.asJson);
        }

        return 0;
    } except BridgeError as error {
        print(f"Cannot reach the planner: {error}", file=sys.stderr);
        print(
            "Start `jac run` in another terminal, or pass --server URL.",
            file=sys.stderr
        );

        return 1;
    } except ValueError as error {
        print(str(error), file=sys.stderr);

        return 2;
    }
}

with entry:__main__ {
    sys.`exit(asyncio.run(main(sys.argv[1:])));
}

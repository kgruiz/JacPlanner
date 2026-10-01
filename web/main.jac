import "./dashboard.css";
import from react { useEffect }
import from "@jac/runtime" { BridgeError }
import from ..core.planner {
    TaskView,
    ListTasks,
    SaveTask,
    SetCompleted,
    DeleteTask,
    ScheduleTask
}

def Today -> str {
    now = new(Date);

    return str(now.getFullYear())
        + "-"
        + str(now.getMonth() + 1).zfill(2)
        + "-"
        + str(now.getDate()).zfill(2);
}

def DisplayDate(value: str) -> str {
    if not value {
        return "No date";
    }
    parts = value.split("-");

    return parts[1] + "/" + parts[2] + "/" + parts[0];
}

def DateKey(date: any) -> str {
    return str(date.getFullYear())
        + "-"
        + str(date.getMonth() + 1).zfill(2)
        + "-"
        + str(date.getDate()).zfill(2);
}

def ShiftDate(value: str, days: int) -> str {
    date = new(Date, value + "T12:00:00");
    date.setDate(date.getDate() + days);
    return DateKey(date);
}

def WeekStart(value: str) -> str {
    date = new(Date, value + "T12:00:00");
    return ShiftDate(value, -int((date.getDay() + 6) % 7));
}

def CourseColor(course: str) -> str {
    total = 0;
    for i in range(len(course)) {
        total += ord(course[i]);
    }
    return ["blue", "purple", "green", "orange"][total % 4];
}

def TimeMinutes(value: str) -> int {
    parts = value.split(":");
    return int(parts[0]) * 60 + int(parts[1]);
}

def TimeLabel(minutes: int) -> str {
    hour = int(minutes / 60) % 24;
    minute = minutes % 60;
    return str(hour % 12 or 12)
        + ":"
        + str(minute).zfill(2)
        + (" AM" if hour < 12 else " PM");
}

def IsOverdue(task: any, today: str) -> bool {
    return not task.completed and bool(task.dueDate) and task.dueDate < today;
}

def ScheduleLabel(task: any) -> str {
    if not task.plannedDate {
        return "Not scheduled";
    }
    return "Scheduled " + DisplayDate(task.plannedDate)
        + (" at " + TimeLabel(TimeMinutes(task.plannedTime)) if task.plannedTime else " (time not set)");
}

def ResizeMinutes(task: any, deltaPixels: float) -> int {
    if abs(deltaPixels) < 4 {
        return task.estimateMinutes;
    }
    maximum = 1440 - TimeMinutes(task.plannedTime);
    snapped = int(Math.round((task.estimateMinutes + deltaPixels * 60 / 64) / 15)) * 15;
    return max(1, min(maximum, snapped));
}

def EventTimeVisible(task: any) -> bool {
    return EventHeight(task) >= 52;
}

def EventCourseVisible(task: any) -> bool {
    return EventHeight(task) >= 72;
}

def EventHeight(task: any) -> float {
    return max(28.0, task.estimateMinutes * 64 / 60);
}

def EventTop(task: any) -> float {
    return min(TimeMinutes(task.plannedTime) * 64 / 60, 1536 - EventHeight(task));
}

def EventStyle(task: any, tasks: list[any]) -> dict[str, str] {
    dayTasks = [
        item
        for item in tasks
        if item.plannedDate == task.plannedDate and item.plannedTime
    ];
    dayTasks.sort(key=lambda (item: any) { return item.plannedTime + item.taskId; });
    dayTasks.sort(key=lambda (item: any) { return EventTop(item); });
    laneEnds: list[float] = [];
    selectedLane = 0;
    selectedGroup = False;

    for item in dayTasks {
        start = EventTop(item);

        if laneEnds and start >= max(laneEnds) {

            if selectedGroup {
                break;
            }

            laneEnds = [];
        }

        lane = 0;
        while lane < len(laneEnds) and laneEnds[lane] > start {
            lane += 1;
        }
        if lane == len(laneEnds) {
            laneEnds = laneEnds + [start + EventHeight(item)];
        } else {
            laneEnds[lane] = start + EventHeight(item);
        }
        if item.taskId == task.taskId {
            selectedLane = lane;
            selectedGroup = True;
        }
    }
    laneCount = max(1, len(laneEnds));
    return {
        "top": str(EventTop(task)) + "px",
        "height": str(EventHeight(task)) + "px",
        "left": "calc(" + str(selectedLane * 100 / laneCount) + "% + 5px)",
        "width": "calc(" + str(100 / laneCount) + "% - 10px)"
    };
}

def CurrentMinutes() -> int {
    now = new(Date);
    return int(now.getHours() * 60 + now.getMinutes());
}

def Field(
    label: str,
    value: str,
    onChange: Callable[[str], None],
    kind: str = "text",
    required: bool = False
) -> JsxElement {
    return
        <label className="field">
            <span>{label}</span>
            <input
                type={kind}
                value={value}
                required={required}
                onChange={lambda (e: ChangeEvent) { onChange(e.target.value); }}
            />
        </label>;
}

def:pub app -> JsxElement {
    has tasks: list[TaskView] = [],
        selectedDate: str = Today(),
        tab: str = "calendar",
        search: str = "",
        weekMode: str = "5",
        plannedTime: str = "",
        nowMinutes: int = CurrentMinutes(),
        status: str = "open",
        courseFilter: str = "",
        loading: bool = True,
        busy: bool = False,
        error: str = "",
        editing: bool = False,
        taskId: str = "",
        title: str = "",
        course: str = "",
        dueDate: str = "",
        priority: str = "medium",
        estimate: str = "30",
        plannedDate: str = Today(),
        notes: str = "",
        resizingId: str = "",
        resizeMinutes: int = 0;

    async def Refresh {
        loading = True;

        try {
            result = await ListTasks();
            tasks = result.tasks;

            if courseFilter
                and not [
                    task
                    for task in result.tasks
                    if task.course == courseFilter
                ] {
                courseFilter = "";
            }
            error = "";
        } except BridgeError as err {
            error = "Cannot reach your planner. Check the server, then refresh.";
        } finally {
            loading = False;
        }
    }

    def Edit(task: TaskView) {
        if busy {
            return;
        }

        taskId = task.taskId;
        title = task.title;
        course = task.course;
        dueDate = task.dueDate;
        priority = task.priority;
        estimate = str(task.estimateMinutes);
        plannedDate = task.plannedDate;
        plannedTime = task.plannedTime;
        notes = task.notes;
        editing = True;
        error = "";
    }

    def NewTask {
        if busy {
            return;
        }

        taskId = "";
        title = "";
        course = "";
        dueDate = "";
        priority = "medium";
        estimate = "30";
        plannedDate = "";
        plannedTime = "";
        notes = "";
        editing = True;
        error = "";
    }

    def NewSlot(day: str, hour: int) {
        NewTask();
        plannedDate = day;
        plannedTime = str(hour).zfill(2) + ":00";
    }

    async def Schedule(scheduledTaskId: str, day: str, hour: int) {
        if busy {
            return;
        }
        busy = True;
        error = "";
        try {
            result = await ScheduleTask(
                scheduledTaskId, day, str(hour).zfill(2) + ":00"
            );
            if result.ok {
                await Refresh();
            } else {
                error = result.error;
            }
        } except BridgeError as err {
            error = "Could not schedule this task. Try again or edit its planned date and time.";
        } finally {
            busy = False;
        }
    }

    async def SaveDuration(task: TaskView, minutes: int) {
        if busy or minutes == task.estimateMinutes {
            return;
        }
        busy = True;
        error = "";
        try {
            result = await SaveTask(task.taskId, task.title, task.course,
                task.dueDate, task.priority, minutes, task.plannedDate,
                task.notes, task.plannedTime);
            if result.ok {
                await Refresh();
            } else {
                error = result.error;
            }
        } except BridgeError as err {
            error = "Could not resize this task. Try again.";
        } finally {
            busy = False;
        }
    }

    def ResizeStart(e: any, task: TaskView) {
        e.preventDefault();
        e.stopPropagation();
        if busy or resizingId or e.button != 0 {
            return;
        }
        resizingId = task.taskId;
        resizeMinutes = task.estimateMinutes;
        startY = e.clientY;
        pointerId = e.pointerId;
        handle: any = e.currentTarget;
        handle.setPointerCapture(pointerId);
        Move = lambda (event: any) {
            if event.pointerId == pointerId {
                resizeMinutes = ResizeMinutes(task, event.clientY - startY);
            }
        };
        Cleanup = lambda {
            handle.removeEventListener("pointermove", Move);
            handle.removeEventListener("pointerup", Finish);
            handle.removeEventListener("pointercancel", Cancel);
            handle.removeEventListener("lostpointercapture", Cancel);
            resizingId = "";
        };
        Finish = lambda (event: any) {
            if event.pointerId == pointerId {
                minutes = ResizeMinutes(task, event.clientY - startY);
                Cleanup();
                SaveDuration(task, minutes);
            }
        };
        Cancel = lambda (event: any) { Cleanup(); };
        handle.addEventListener("pointermove", Move);
        handle.addEventListener("pointerup", Finish);
        handle.addEventListener("pointercancel", Cancel);
        handle.addEventListener("lostpointercapture", Cancel);
    }

    def PreviewTask(task: TaskView) -> any {
        return {**task, "estimateMinutes": resizeMinutes} if resizingId == task.taskId else task;
    }

    async def Save {
        if busy {
            return;
        }

        if not estimate.isdigit() {
            error = "Estimated minutes must be a whole number from 1 to 1440.";

            return;
        }
        busy = True;
        error = "";

        try {
            result = await SaveTask(
                taskId,
                title,
                course,
                dueDate,
                priority,
                int(estimate),
                plannedDate,
                notes,
                plannedTime
            );

            if result.ok {
                editing = False;
                await Refresh();
            } else {
                error = result.error;
            }
        } except BridgeError as err {
            error = "Could not save. Your draft is still here. Try again.";
        } finally {
            busy = False;
        }
    }

    async def Toggle(task: TaskView) {
        if busy {
            return;
        }

        busy = True;
        error = "";

        try {
            result = await SetCompleted(task.taskId, not task.completed);

            if result.ok {
                await Refresh();
            } else {
                error = result.error;
            }
        } except BridgeError as err {
            error = "Could not update this task. Refresh and try again.";
        } finally {
            busy = False;
        }
    }

    async def Remove(task: TaskView) {
        if busy {
            return;
        }

        if not window.confirm("Delete " + task.title + "? This cannot be undone.") {
            return;
        }
        busy = True;
        error = "";

        try {
            result = await DeleteTask(task.taskId);

            if result.ok {
                await Refresh();
            } else {
                error = result.error;
            }
        } except BridgeError as err {
            error = "Could not delete this task. Refresh and try again.";
        } finally {
            busy = False;
        }
    }

    async can with entry {
        await Refresh();
        window.setTimeout(
            lambda {
                grid: any = document.getElementById("calendar-scroll");
                if grid {
                    grid.scrollTop = 8 * 64;
                }
            },
            100
        );
    }

    filteredTasks = [
        task
        for task in tasks
        if (not courseFilter or task.course == courseFilter)
            and (
                not search
                or search.lower()
                    in (task.title + " " + task.course + " " + task.notes).lower()
            )
            and (
                status == "all"
                or (task.completed if status == "done" else not task.completed)
            )
    ];
    trayTasks = [
        task
        for task in filteredTasks
        if not task.plannedTime
    ];
    courses: list[str] = [];
    for task in tasks {
        if task.course and task.course not in courses {
            courses = courses + [task.course];
        }
    }
    start = WeekStart(selectedDate);
    days = [ShiftDate(start, offset) for offset in range(int(weekMode))];
    useEffect(
        lambda {
            timer = window.setInterval(
                lambda { nowMinutes = CurrentMinutes(); }, 30000
            );
            return lambda { window.clearInterval(timer); };
        },
        []
    );
    useEffect(
        lambda {

            if not editing {
                return;
            }

            opener: any = document.activeElement;
            editor: any = document.getElementById("task-editor");
            titleInput: any = editor.querySelector("input");
            titleInput.focus();
            handleKeyDown = lambda (e: any) {

                if e.key == "Escape" {
                    e.preventDefault();

                    if not busy {
                        editing = False;
                    }
                }

                if e.key == "Tab" {
                    controls: any = editor.querySelectorAll(
                        "button:not(:disabled), input:not(:disabled), select:not(:disabled), textarea:not(:disabled)"
                    );

                    if len(controls) == 0 {
                        e.preventDefault();
                        editor.focus();
                    } else {
                        first: any = controls[0];
                        last: any = controls[len(controls) - 1];

                        if not editor.contains(document.activeElement)
                            or (e.shiftKey and document.activeElement == first)
                            or (not e.shiftKey and document.activeElement == last) {
                            e.preventDefault();
                            (last if e.shiftKey else first).focus();
                        }
                    }
                }
            };
            document.addEventListener("keydown", handleKeyDown, True);

            return lambda {
                document.removeEventListener("keydown", handleKeyDown, True);

                if opener and opener.isConnected and not opener.matches(":disabled") {
                    opener.focus();
                } else {
                    fallback: any = document.querySelector(".new-task:not(:disabled), .nav-tab.active");

                    if fallback {
                        fallback.focus();
                    }
                }
            };
        },
        [editing]
    );
    useEffect(
        lambda {

            if editing and not busy {
                editor: any = document.getElementById("task-editor");

                if editor and not editor.contains(document.activeElement) {
                    editor.querySelector("input").focus();
                }
            }
        },
        [editing, busy]
    );

    return
        <main className="shell">
            <header className="masthead" inert={editing}>
                <div className="brand">JacPlanner</div>
                <nav aria-label="Planner views">
                    <button
                        className={"nav-tab active" if tab == "calendar" else "nav-tab"}
                        onClick={lambda {
                            tab = "calendar";
                            status = "open";
                        }}
                    >
                        Calendar
                    </button>
                    <button
                        className={"nav-tab active" if tab == "tasks" else "nav-tab"}
                        onClick={lambda { tab = "tasks"; }}
                    >
                        Tasks
                    </button>
                </nav>
                <input
                    className="search"
                    aria-label="Search tasks"
                    placeholder="Search tasks, courses, or notes..."
                    value={search}
                    onChange={lambda (e: ChangeEvent) { search = e.target.value; }}
                />
                <button
                    className="quiet refresh"
                    aria-label="Refresh tasks"
                    title="Refresh tasks"
                    disabled={busy or loading}
                    onClick={lambda { Refresh(); }}
                >
                    <svg width="20" height="20" viewBox="0 0 24 24" fill="none" stroke="currentColor" strokeWidth="2" aria-hidden="true">
                        <path d="M20 7v5h-5M4 17v-5h5"/>
                        <path d="M6.1 7a7 7 0 0 1 11.6-2L20 8M4 16l2.3 3A7 7 0 0 0 18 17"/>
                    </svg>
                </button>
            </header>
            {<p className="error" role="alert">{error}</p>
                if error and not editing
                else <span/>}
            <div className={"layout tasks-layout" if tab == "tasks" else "layout"} inert={editing}>
                {<aside className="tray">
                    <div className="section-heading">
                        <h2>To schedule</h2>
                        <span className="count">{str(len(trayTasks))}</span>
                    </div>
                    <select
                        aria-label="Filter by course"
                        value={courseFilter}
                        onChange={lambda (e: ChangeEvent) { courseFilter = e.target.value; }}
                    >
                        <option value="">All courses</option>
                        {[
                            <option key={value} value={value}>{value}</option>
                            for value in courses
                        ]}
                    </select>
                    <p className="tray-hint">
                        Drag a task onto the calendar, or select it to plan a time.
                    </p>
                    {<p className="empty" role="status">Loading your tasks...</p>
                        if loading
                        else <span/>}
                    {<p className="empty">
                        All caught up. Add a task to make room for what's next.
                    </p>
                        if not loading and len(trayTasks) == 0
                        else <span/>}
                    {[
                        <article
                            className={"tray-task overdue" if IsOverdue(task, Today()) else "tray-task"}
                            key={task.taskId}
                            draggable={not busy}
                            onDragStart={lambda (e: any) { e.dataTransfer.setData(
                                "text/plain", task.taskId
                            ); }}
                        >
                            <button
                                className="check"
                                aria-label={"Reopen " + task.title
                                    if task.completed
                                    else "Complete " + task.title}
                                aria-pressed={task.completed}
                                disabled={busy}
                                onClick={lambda { Toggle(task); }}
                            >
                                {"✓" if task.completed else ""}
                            </button>
                            <span className={"dot " + CourseColor(task.course)}/>
                            <button
                                className="tray-title"
                                disabled={busy}
                                onClick={lambda { Edit(task); }}
                            >
                                <strong
                                    className={"completed" if task.completed else ""}
                                >
                                    {task.title}
                                </strong>
                                <span>{task.course or "Personal"}</span>
                                {<span className="overdue-label">Overdue</span> if IsOverdue(task, Today()) else <span/>}
                            </button>
                            <span className="duration">
                                {str(task.estimateMinutes)} min
                            </span>
                        </article> for task in trayTasks
                    ]}
                </aside> if tab == "calendar" else <span hidden/>}
                <section className="workspace" aria-label="Planner">
                    <div className="toolbar">
                        {<div className="calendar-controls">
                        <h1>
                            {new(Date, start + "T12:00:00").toLocaleDateString(
                                "en-US", {"month": "long", "day": "numeric"}
                            )} - {new(
                                Date, days[len(days) - 1] + "T12:00:00"
                            ).toLocaleDateString(
                                "en-US",
                                {"month": "long", "day": "numeric", "year": "numeric"}
                            )}
                        </h1>
                        <button
                            className="secondary"
                            onClick={lambda { selectedDate = Today(); }}
                        >
                            Today
                        </button>
                        <button
                            className="secondary arrow"
                            aria-label="Previous week"
                            onClick={lambda { selectedDate = ShiftDate(
                                selectedDate, -7
                            ); }}
                        >
                            ‹
                        </button>
                        <button
                            className="secondary arrow"
                            aria-label="Next week"
                            onClick={lambda { selectedDate = ShiftDate(
                                selectedDate, 7
                            ); }}
                        >
                            ›
                        </button>
                        <select
                            aria-label="Calendar days"
                            value={weekMode}
                            onChange={lambda (e: ChangeEvent) { weekMode = e.target.value; }}
                        >
                            <option value="7">Full week</option>
                            <option value="5">Weekdays</option>
                        </select>
                        </div> if tab == "calendar" else <h1>Tasks</h1>}
                        <button
                            className="primary new-task"
                            disabled={busy}
                            onClick={NewTask}
                        >
                            ＋ New task
                        </button>
                    </div>
                    {<div className="calendar-scroll" id="calendar-scroll">
                        <div className="calendar" style={{"--days": weekMode}}>
                            <div className="day-heading time-heading"/>
                            {[
                                <div className="day-heading" key={day}>
                                    <span className={"today" if day == Today() else ""}>
                                        {new(
                                            Date, day + "T12:00:00"
                                        ).toLocaleDateString(
                                            "en-US",
                                            {"weekday": "short", "day": "numeric"}
                                        )}
                                    </span>
                                </div> for day in days
                            ]}
                            <div className="all-day-label">All-day / due</div>
                            {[
                                <div className="all-day" key={day}>
                                    {[
                                        <button
                                            className={"deadline overdue" if IsOverdue(task, Today()) else "deadline"}
                                            key={task.taskId}
                                            disabled={busy}
                                            onClick={lambda { Edit(task); }}
                                        >
                                            <span
                                                className={"dot "
                                                    + CourseColor(task.course)}
                                            />
                                            {task.title}
                                            {" · overdue" if IsOverdue(task, Today()) else " · due"
                                                if task.dueDate == day
                                                else " · planned"}
                                        </button>
                                        for task in filteredTasks
                                        if task.dueDate == day
                                            or (
                                                task.plannedDate == day
                                                and not task.plannedTime
                                            )
                                    ]}
                                </div> for day in days
                            ]}
                            <div className="time-axis">
                                {[
                                    <span
                                        className="hour-label"
                                        key={hour}
                                        style={{"top": str(hour * 64) + "px"}}
                                    >
                                        {TimeLabel(hour * 60)}
                                    </span> for hour in range(24)
                                ]}
                            </div>
                            {[
                                <div
                                    className="day-grid"
                                    key={day}
                                    onDragOver={lambda (e: any) { e.preventDefault(); }}
                                    onDrop={lambda (e: any) {
                                        e.preventDefault();
                                        droppedTaskId = e.dataTransfer.getData("text/plain");

                                        if droppedTaskId {
                                            hour = min(23, max(0, int((
                                                e.clientY - e.currentTarget.getBoundingClientRect().top
                                            ) / 64)));
                                            Schedule(droppedTaskId, day, hour);
                                        }
                                    }}
                                >
                                    {[
                                        <button
                                            className="time-slot"
                                            key={hour}
                                            aria-label={"Add task on "
                                                + DisplayDate(day)
                                                + " at "
                                                + TimeLabel(hour * 60)}
                                            disabled={busy}
                                            onClick={lambda { NewSlot(day, hour); }}
                                        /> for hour in range(24)
                                    ]}{[
                                        <div
                                            title={task.title
                                                + " · "
                                                + task.course
                                                + " · "
                                                + task.plannedTime
                                                + " · "
                                                + str(task.estimateMinutes)
                                                + " min"}
                                            aria-label={"Edit "
                                                + task.title
                                                + " at "
                                                + task.plannedTime}
                                            className={"event "
                                                + CourseColor(task.course)
                                                + (" overdue" if IsOverdue(task, Today()) else "")
                                                + (
                                                    " completed"
                                                        if task.completed
                                                        else ""
                                                )}
                                            key={task.taskId}
                                            draggable={not busy and not resizingId}
                                            onDragStart={lambda (e: any) { e.dataTransfer.setData(
                                                "text/plain", task.taskId
                                            ); }}
                                            style={EventStyle(PreviewTask(task), [PreviewTask(item) for item in filteredTasks])}
                                        >
                                            <button className="event-content" aria-label={"Edit " + task.title + ", " + TimeLabel(TimeMinutes(task.plannedTime)) + ", " + str(PreviewTask(task).estimateMinutes) + " minutes" + (", overdue" if IsOverdue(task, Today()) else "")} disabled={busy or bool(resizingId)} onClick={lambda { Edit(task); }}>
                                                <strong>{task.title}</strong>
                                                {<span>{TimeLabel(TimeMinutes(task.plannedTime))} - {TimeLabel(TimeMinutes(task.plannedTime) + PreviewTask(task).estimateMinutes)}</span> if EventTimeVisible(PreviewTask(task)) else <span/>}
                                                {<span>{task.course or "Personal"}</span> if EventCourseVisible(PreviewTask(task)) else <span/>}
                                                {<span className="overdue-label">Overdue</span> if IsOverdue(task, Today()) and EventHeight(PreviewTask(task)) >= 90 else <span/>}
                                            </button>
                                            <button className="resize-handle" aria-label={"Resize " + task.title + ", " + str(PreviewTask(task).estimateMinutes) + " minutes. Use up or down arrows."} title="Drag to resize; arrow keys adjust by 15 minutes" disabled={busy}
                                                onPointerDown={lambda (e: any) { ResizeStart(e, task); }}
                                                onClick={lambda (e: any) { e.preventDefault(); e.stopPropagation(); }}
                                                onDragStart={lambda (e: any) { e.preventDefault(); e.stopPropagation(); }}
                                                onKeyDown={lambda (e: any) {
                                                    if e.key == "ArrowUp" or e.key == "ArrowDown" {
                                                        e.preventDefault();
                                                        e.stopPropagation();
                                                        SaveDuration(task, max(1, min(1440 - TimeMinutes(task.plannedTime), task.estimateMinutes + (-15 if e.key == "ArrowUp" else 15))));
                                                    }
                                                }}
                                            />
                                        </div>
                                        for task in filteredTasks
                                        if task.plannedDate == day and task.plannedTime
                                    ]}{<div
                                        className="now-line"
                                        style={{
                                            "top": str(nowMinutes * 64 / 60) + "px"
                                        }}
                                    >
                                        <span>{TimeLabel(nowMinutes)}</span>
                                    </div>
                                        if day == Today()
                                        else <span/>}
                                </div> for day in days
                            ]}
                        </div>
                    </div>
                        if tab == "calendar"
                        else <div className="tasks-view">
                            <div className="section-heading task-filters">
                                <span className="count">{str(len(filteredTasks)) + " tasks"}</span>
                                <select aria-label="Filter by course" value={courseFilter} onChange={lambda (e: ChangeEvent) { courseFilter = e.target.value; }}>
                                    <option value="">All courses</option>
                                    {[<option key={value} value={value}>{value}</option> for value in courses]}
                                </select>
                                <select
                                    aria-label="Filter task status"
                                    value={status}
                                    onChange={lambda (e: ChangeEvent) { status = e.target.value; }}
                                >
                                    <option value="open">Open tasks</option>
                                    <option value="done">Completed</option>
                                    <option value="all">All tasks</option>
                                </select>
                            </div>
                            {<p className="empty">No tasks match your filters.</p>
                                if not loading and len(filteredTasks) == 0
                                else <span/>}
                            {[
                                <article className={"task-card overdue" if IsOverdue(task, Today()) else "task-card"} key={task.taskId}>
                                    <button
                                        className="check"
                                        aria-label={"Reopen " + task.title
                                            if task.completed
                                            else "Complete " + task.title}
                                        aria-pressed={task.completed}
                                        disabled={busy}
                                        onClick={lambda { Toggle(task); }}
                                    >
                                        {"✓" if task.completed else ""}
                                    </button>
                                    <div className="task-body">
                                        <div className="task-top">
                                            <h3 className={"completed" if task.completed else ""}>{task.title}</h3>
                                            <span className={"course-tag " + CourseColor(task.course)}>{task.course or "Personal"}</span>
                                            <span className="priority" data-priority={task.priority}>{task.priority} priority</span>
                                        </div>
                                        <div className="task-meta">
                                            <span>{str(task.estimateMinutes)} min</span>
                                            <span className={"deadline-meta overdue-label" if IsOverdue(task, Today()) else "deadline-meta"}>{"Overdue · Due " + DisplayDate(task.dueDate) if IsOverdue(task, Today()) else "Due " + DisplayDate(task.dueDate) if task.dueDate else "No deadline"}</span>
                                            <span className="schedule-meta">{ScheduleLabel(task)}</span>
                                        </div>
                                        {<p className="notes">{task.notes}</p>
                                            if task.notes
                                            else <span/>}
                                    </div>
                                    <div className="task-actions">
                                        <button className="quiet" disabled={busy} onClick={lambda { Edit(task); }}>Edit</button>
                                        <details className="task-menu">
                                            <summary aria-label={"More actions for " + task.title}>⋯</summary>
                                            <button className="danger" disabled={busy} onClick={lambda { Remove(task); }}>Delete</button>
                                        </details>
                                    </div>
                                </article> for task in filteredTasks
                            ]}
                        </div>}
                </section>
            </div>
            {<div
                className="modal-backdrop"
                onClick={lambda (e: any) { if e.target == e.currentTarget and not busy {
                    editing = False;
                }}}
            >
                <section
                    className="editor"
                    id="task-editor"
                    tabIndex={-1}
                    role="dialog"
                    aria-modal="true"
                    aria-label={"Edit task" if taskId else "New task"}
                >
                    <div className="section-heading">
                        <h2>{"Edit task" if taskId else "New task"}</h2>
                        <button
                            className="quiet"
                            disabled={busy}
                            onClick={lambda { editing = False; }}
                        >
                            Close
                        </button>
                    </div>
                    <form
                        onSubmit={lambda (e: FormEvent) {
                            e.preventDefault();
                            Save();
                        }}
                    >
                        <fieldset className="editor-fields" disabled={busy}>
                            <Field
                                label="Title"
                                value={title}
                                required={True}
                                onChange={lambda (value: str) { title = value; }}
                            />
                            <Field
                                label="Course"
                                value={course}
                                onChange={lambda (value: str) { course = value; }}
                            />
                            <div className="form-grid">
                                <Field
                                    label="Due date (optional)"
                                    value={dueDate}
                                    kind="date"
                                    onChange={lambda (value: str) { dueDate = value; }}
                                />
                                <Field
                                    label="Planned date (optional)"
                                    value={plannedDate}
                                    kind="date"
                                    onChange={lambda (value: str) { plannedDate = value; }}
                                />
                                <Field
                                    label="Planned time (optional)"
                                    value={plannedTime}
                                    kind="time"
                                    onChange={lambda (value: str) { plannedTime = value; }}
                                />
                                <label className="field">
                                    <span>Priority</span>
                                    <select
                                        value={priority}
                                        onChange={lambda (e: ChangeEvent) { priority = e.target.value; }}
                                    >
                                        <option value="low">Low</option>
                                        <option value="medium">Medium</option>
                                        <option value="high">High</option>
                                    </select>
                                </label>
                                <Field
                                    label="Estimated minutes (1-1440)"
                                    value={estimate}
                                    kind="number"
                                    required={True}
                                    onChange={lambda (value: str) { estimate = value; }}
                                />
                            </div>
                            <label className="field">
                                <span>Notes</span>
                                <textarea
                                    rows={3}
                                    value={notes}
                                    onChange={lambda (e: ChangeEvent) { notes = e.target.value; }}
                                />
                            </label>
                            {<p className="error" role="alert">{error}</p>
                                if error
                                else <span/>}
                            <button className="primary" type="submit" disabled={busy}>
                                {"Saving..." if busy else "Save task"}
                            </button>
                        </fieldset>
                    </form>
                </section>
            </div>
                if editing
                else <span/>}
        </main>;
}

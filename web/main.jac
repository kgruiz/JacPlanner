import "./dashboard.css";
import from "@jac/runtime" { BridgeError }
import from ..core.planner { TaskView, ListTasks, SaveTask, SetCompleted, DeleteTask }

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
        return "Unscheduled";
    }
    parts = value.split("-");

    return parts[1] + "/" + parts[2] + "/" + parts[0];
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
        notes: str = "";

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
        taskId = task.taskId;
        title = task.title;
        course = task.course;
        dueDate = task.dueDate;
        priority = task.priority;
        estimate = str(task.estimateMinutes);
        plannedDate = task.plannedDate;
        notes = task.notes;
        editing = True;
        error = "";
    }

    def NewTask {
        taskId = "";
        title = "";
        course = "";
        dueDate = "";
        priority = "medium";
        estimate = "30";
        plannedDate = selectedDate;
        notes = "";
        editing = True;
        error = "";
    }

    async def Save {
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
                notes
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
    }

    filteredTasks = [
        task
        for task in tasks
        if (not courseFilter or task.course == courseFilter)
            and (
                status == "all"
                or (task.completed if status == "done" else not task.completed)
            )
    ];
    dayTasks = [
        task
        for task in tasks
        if task.plannedDate == selectedDate
    ];
    openTasks = [
        task
        for task in tasks
        if not task.completed
    ];
    dayOpenTasks = [
        task
        for task in dayTasks
        if not task.completed
    ];
    minutes = 0;

    for task in dayOpenTasks {
        minutes += task.estimateMinutes;
    }
    courses: list[str] = [];

    for task in tasks {
        if task.course and task.course not in courses {
            courses = courses + [task.course];
        }
    }

    return
        <main className="shell">
            <header className="masthead">
                <div className="brand">
                    <span className="brand-mark">J</span>
                    <span>JacPlanner</span>
                </div>
                <span className="semester">FALL 2026 / COURSEWORK</span>
            </header>
            <section className="intro">
                <div>
                    <p className="eyebrow">YOUR WORK, WITH ROOM TO BREATHE</p>
                    <h1>A calmer plan.</h1>
                    <p className="muted">
                        Turn the semester into one manageable day at a time.
                    </p>
                </div>
                <button className="primary" onClick={NewTask} disabled={busy}>
                    + New task
                </button>
            </section>
            {<p className="error" role="alert">{error}</p> if error else <span/>}
            <div className="layout">
                <section className="tasks-panel" aria-label="Coursework tasks">
                    <div className="section-heading">
                        <h2>
                            Your coursework{" "}
                            <span className="count">{str(len(openTasks))} open</span>
                        </h2>
                        <button
                            className="quiet"
                            disabled={busy or loading}
                            onClick={lambda {
                                error = "";
                                Refresh();
                            }}
                        >
                            Refresh
                        </button>
                    </div>
                    <div className="filters">
                        <label className="field">
                            <span>Status</span>
                            <select
                                value={status}
                                onChange={lambda (e: ChangeEvent) { status = e.target.value; }}
                            >
                                <option value="open">Open tasks</option>
                                <option value="done">Completed</option>
                                <option value="all">All tasks</option>
                            </select>
                        </label>
                        <label className="field">
                            <span>Course</span>
                            <select
                                value={courseFilter}
                                onChange={lambda (e: ChangeEvent) { courseFilter = e.target.value; }}
                            >
                                <option value="">All courses</option>
                                {[
                                    <option key={value} value={value}>{value}</option>
                                    for value in courses
                                ]}
                            </select>
                        </label>
                    </div>
                    {<p className="empty" role="status">Loading your coursework...</p>
                        if loading
                        else <span/>}
                    {<div className="empty">
                        <span className="empty-icon">✓</span>
                        <h3>Room for what's next.</h3>
                        <p>
                            No tasks match these filters. Add coursework or choose another view.
                        </p>
                    </div>
                        if not loading and len(filteredTasks) == 0
                        else <span/>}
                    <div className="task-list">
                        {[
                            <article className="task-card" key={task.taskId}>
                                <button
                                    className="check"
                                    aria-label={"Reopen " + task.title
                                        if task.completed
                                        else "Complete " + task.title}
                                    aria-pressed={task.completed}
                                    disabled={busy or loading}
                                    onClick={lambda { Toggle(task); }}
                                >
                                    {"✓" if task.completed else ""}
                                </button>
                                <div className="task-body">
                                    <div className="task-top">
                                        <span className="course-tag">
                                            {task.course or "PERSONAL"}
                                        </span>
                                        <span
                                            className="priority"
                                            data-priority={task.priority}
                                        >
                                            {task.priority} priority
                                        </span>
                                    </div>
                                    <h3
                                        className={"completed"
                                            if task.completed
                                            else ""}
                                    >
                                        {task.title}
                                    </h3>
                                    <p className="task-meta">
                                        {str(task.estimateMinutes)}{" "}
                                        min{" "}
                                        <span>·</span>{" "}
                                        Due{" "}
                                        {DisplayDate(task.dueDate)}{" "}
                                        <span>·</span>{" "}
                                        Plan{" "}
                                        {DisplayDate(task.plannedDate)}
                                    </p>
                                    {<p className="notes">{task.notes}</p>
                                        if task.notes
                                        else <span/>}
                                    <div className="task-actions">
                                        <button
                                            className="quiet"
                                            disabled={busy}
                                            onClick={lambda { Edit(task); }}
                                        >
                                            Edit task
                                        </button>
                                        <button
                                            className="danger"
                                            disabled={busy}
                                            onClick={lambda { Remove(task); }}
                                        >
                                            Delete
                                        </button>
                                    </div>
                                </div>
                            </article> for task in filteredTasks
                        ]}
                    </div>
                </section>
                <aside className="day-panel">
                    <p className="eyebrow">MAKE SPACE FOR TODAY</p>
                    <h2>Your daily plan</h2>
                    <Field
                        label="Plan for"
                        value={selectedDate}
                        kind="date"
                        onChange={lambda (value: str) { selectedDate = value; }}
                    />
                    <button
                        className="quiet"
                        onClick={lambda { selectedDate = Today(); }}
                    >
                        Jump to today
                    </button>
                    <div className="workload">
                        <strong>{str(minutes)}</strong>
                        <span>minutes remaining</span>
                        <p>
                            {str(len(dayOpenTasks))} open / {str(len(dayTasks))} planned
                        </p>
                    </div>
                    <p className="daily-date">{DisplayDate(selectedDate)}</p>
                    {<p className="muted">
                        A clear day. Plan a task when you're ready.
                    </p>
                        if len(dayTasks) == 0
                        else <span/>}
                    <div className="daily-list">
                        {[
                            <div className="daily-task" key={task.taskId}>
                                <span>{"✓" if task.completed else "○"}</span>
                                <div>
                                    <strong>{task.title}</strong>
                                    <p>
                                        {task.course or "Personal"} · {str(
                                            task.estimateMinutes
                                        )} min
                                    </p>
                                </div>
                            </div> for task in dayTasks
                        ]}
                    </div>
                    <button className="secondary" disabled={busy} onClick={NewTask}>
                        + Plan a task
                    </button>
                </aside>
            </div>
            {<div className="modal-backdrop">
                <section
                    className="editor"
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
                    </form>
                </section>
            </div>
                if editing
                else <span/>}
            <footer className="footer">One task at a time. You've got this.</footer>
        </main>;
}

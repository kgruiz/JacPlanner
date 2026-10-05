obj:pub TaskView {
    has taskId: str = "",
        title: str = "",
        course: str = "",
        dueDate: str = "",
        priority: str = "medium",
        estimateMinutes: int = 30,
        plannedDate: str = "",
        plannedTime: str = "",
        notes: str = "",
        completed: bool = False,
        recurrence: str = "none";
}

obj:pub TaskList {
    has tasks: list[TaskView] = [];
}

obj:pub TaskResult {
    has ok: bool = False,
        error: str = "",
        task: TaskView | None = None;
}

import from datetime { date }
import from core.models { TaskView, TaskList, TaskResult }

node Task {
    has title: str = "",
        course: str = "",
        dueDate: str = "",
        priority: str = "medium",
        estimateMinutes: int = 30,
        plannedDate: str = "",
        notes: str = "",
        completed: bool = False;

    def ToView -> TaskView {
        return TaskView(
            taskId=jid(self),
            title=self.title,
            course=self.course,
            dueDate=self.dueDate,
            priority=self.priority,
            estimateMinutes=self.estimateMinutes,
            plannedDate=self.plannedDate,
            notes=self.notes,
            completed=self.completed
        );
    }
}

def:priv ValidDate(value: str) -> bool {
    if value == "" {
        return True;
    }

    try {
        parsed = date.fromisoformat(value);

        return parsed.isoformat() == value;
    } except ValueError {
        return False;
    }
}

def:priv FindTask(taskId: str) -> Task | None {
    for task in [root-->[?:Task]] {
        if jid(task) == taskId {
            return task;
        }
    }

    return None;
}

def:pub ListTasks -> TaskList {
    return TaskList(tasks=[task.ToView() for task in [root-->[?:Task]]]);
}

def:pub SaveTask(
    taskId: str = "",
    title: str = "",
    course: str = "",
    dueDate: str = "",
    priority: str = "medium",
    estimateMinutes: int = 30,
    plannedDate: str = "",
    notes: str = ""
) -> TaskResult {
    cleanTitle = title.strip();
    # Jac 0.37.23's REST binder supplies omitted numeric defaults as strings.
    estimateMinutes = int(estimateMinutes);

    if not cleanTitle {
        return TaskResult(error="Title is required.");
    }

    if priority not in ["low", "medium", "high"] {
        return TaskResult(error="Priority must be low, medium, or high.");
    }

    if estimateMinutes < 1 or estimateMinutes > 1440 {
        return TaskResult(error="Estimated minutes must be between 1 and 1440.");
    }

    if not ValidDate(dueDate) or not ValidDate(plannedDate) {
        return TaskResult(error="Dates must be valid YYYY-MM-DD values or blank.");
    }

    task = FindTask(taskId) if taskId else None;

    if taskId and task is None {
        return TaskResult(error="Task was not found.");
    }

    if task is None {
        task = root ++> Task();
    }
    task.title = cleanTitle;
    task.course = course.strip();
    task.dueDate = dueDate;
    task.priority = priority;
    task.estimateMinutes = estimateMinutes;
    task.plannedDate = plannedDate;
    task.notes = notes;

    return TaskResult(ok=True, task=task.ToView());
}

def:pub SetCompleted(taskId: str, completed: bool) -> TaskResult {
    task = FindTask(taskId);

    if task is None {
        return TaskResult(error="Task was not found.");
    }
    task.completed = completed;

    return TaskResult(ok=True, task=task.ToView());
}

def:pub DeleteTask(taskId: str) -> TaskResult {
    task = FindTask(taskId);

    if task is None {
        return TaskResult(error="Task was not found.");
    }
    taskView = task.ToView();
    del task;

    return TaskResult(ok=True, task=taskView);
}

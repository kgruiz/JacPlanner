test "calendar dates reject impossible and noncanonical input" {
    assert PlanDate("2026-09-30") == "2026-09-30";
    assert PlanDate("none") == "";
    assert PlanDate("today") == datetime.date.today().isoformat();

    with testraises(ValueError) {
        PlanDate("2026-02-30");
    }

    with testraises(ValueError) {
        PlanDate("20260930");
    }
}

test "task prefixes never silently choose an ambiguous task" {
    tasks = [TaskView(taskId="abc123"), TaskView(taskId="abc456")];
    assert ResolveTask(tasks, "abc1").taskId == "abc123";

    with testraises(ValueError) {
        ResolveTask(tasks, "abc");
    }

    with testraises(ValueError) {
        ResolveTask(tasks, "missing");
    }

    with testraises(ValueError) {
        ResolveTask(tasks, "");
    }
}

test "JSON output preserves numeric and boolean task fields" {
    task = TaskView(
        taskId="example",
        title="Assignment",
        course="EECS 449",
        dueDate="",
        priority="high",
        estimateMinutes=45,
        plannedDate="",
        notes="",
        completed=True
    );
    record = json.loads(json.dumps(TaskData(task)));
    assert record["estimateMinutes"] == 45;
    assert record["completed"] == True;
    assert record["taskId"] == "example";
}

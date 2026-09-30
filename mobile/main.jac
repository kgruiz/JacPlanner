import from "@jac/mobui" {
    View,
    Text,
    Pressable,
    TextInput,
    ScrollView,
    KeyboardAvoidingView,
    Keyboard,
    Platform,
    ActivityIndicator
}
import from "@jac/runtime" { BridgeError }
import from ..core.planner { ListTasks, SaveTask, SetCompleted, TaskView }
import from .theme { styles }

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

    return parts[1] + "/" + parts[2] + "/" + parts[0] if len(parts) == 3 else value;
}

def Field(
    label: str,
    value: str,
    onChange: Callable[[str], None],
    placeholder: str = "",
    multiline: bool = False
) -> JsxElement {
    return
        <View style={{"gap": 7}}>
            <Text style={styles.label}>{label}</Text>
            <TextInput
                style={styles.input}
                value={value}
                onChangeText={onChange}
                placeholder={placeholder}
                placeholderTextColor="#74838A"
                accessibilityLabel={label}
                autoCapitalize="none"
                multiline={multiline}
            />
        </View>;
}

def:pub app -> JsxElement {
    has tasks: list[TaskView] = [],
        selectedDate: str = Today(),
        loading: bool = True,
        busy: bool = False,
        adding: bool = False,
        error: str = "",
        title: str = "",
        course: str = "",
        dueDate: str = "",
        priority: str = "medium",
        estimate: str = "30",
        plannedDate: str = Today(),
        notes: str = "";

    async def Refresh {
        loading = True;
        error = "";

        try {
            result = await ListTasks();
            tasks = result.tasks;
        } except BridgeError as err {
            error = "Cannot reach the planner. Check that the local server is running, then refresh.";
        } finally {
            loading = False;
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

    async def Add -> None {
        if not estimate.isdigit() {
            error = "Enter estimated minutes as a whole number from 1 to 1440.";

            return;
        }

        busy = True;
        error = "";

        try {
            result = await SaveTask(
                "", title, course, dueDate, priority, int(estimate), plannedDate, notes
            );

            if result.ok {
                title = "";
                course = "";
                dueDate = "";
                notes = "";
                adding = False;
                Keyboard.dismiss();
                await Refresh();
            } else {
                error = result.error;
            }
        } except BridgeError as err {
            error = "Could not save the task. Check the server and try again.";
        } finally {
            busy = False;
        }
    }

    async can with entry {
        await Refresh();
    }

    dayTasks = [
        task
        for task in tasks
        if task.plannedDate == selectedDate
    ];
    minutes = 0;

    for task in dayTasks {
        if not task.completed {
            minutes += task.estimateMinutes;
        }
    }

    return
        <KeyboardAvoidingView
            style={styles.screen}
            behavior={"padding" if Platform.OS == "ios" else "height"}
        >
            <ScrollView
                contentContainerStyle={styles.body}
                keyboardShouldPersistTaps="handled"
            >
                <View style={{"gap": 6}}>
                    <Text style={styles.subtitle}>JACPLANNER / COURSEWORK</Text>
                    <Text style={styles.heading}>A calmer day.</Text>
                    <Text style={styles.subtitle}>
                        Make room for the work that matters.
                    </Text>
                </View>
                <View style={styles.row}>
                    <Pressable
                        style={styles.button}
                        onPress={lambda {
                            adding = not adding;
                            error = "";
                        }}
                        accessibilityRole="button"
                    >
                        <Text style={styles.buttonText}>
                            {"Close form" if adding else "Add task"}
                        </Text>
                    </Pressable>
                    <Pressable
                        style={styles.secondary}
                        disabled={loading or busy}
                        onPress={Refresh}
                        accessibilityRole="button"
                    >
                        <Text style={styles.secondaryText}>Refresh</Text>
                    </Pressable>
                </View>
                {<Text style={styles.error} accessibilityRole="alert">{error}</Text>
                    if error
                    else <View/>}
                {<ActivityIndicator
                    color="#176F68"
                    accessibilityLabel="Loading planner"
                />
                    if loading or busy
                    else <View/>}
                {<View style={styles.card}>
                    <Text style={styles.heading}>New task</Text>
                    <Field
                        label="Title"
                        value={title}
                        onChange={lambda (value: str) { title = value; }}
                    />
                    <Field
                        label="Course"
                        value={course}
                        onChange={lambda (value: str) { course = value; }}
                        placeholder="EECS 449"
                    />
                    <Field
                        label="Due date (YYYY-MM-DD, optional)"
                        value={dueDate}
                        onChange={lambda (value: str) { dueDate = value; }}
                    />
                    <Text style={styles.label}>Priority</Text>
                    <View style={styles.row}>
                        {[
                            <Pressable
                                key={level}
                                style={styles.button
                                    if level == priority
                                    else styles.secondary}
                                accessibilityRole="button"
                                accessibilityState={{"selected": level == priority}}
                                onPress={lambda { priority = level; }}
                            >
                                <Text
                                    style={styles.buttonText
                                        if level == priority
                                        else styles.secondaryText}
                                >
                                    {level}
                                </Text>
                            </Pressable> for level in ["low", "medium", "high"]
                        ]}
                    </View>
                    <Field
                        label="Estimated minutes (1-1440)"
                        value={estimate}
                        onChange={lambda (value: str) { estimate = value; }}
                    />
                    <Field
                        label="Planned date (YYYY-MM-DD, optional)"
                        value={plannedDate}
                        onChange={lambda (value: str) { plannedDate = value; }}
                    />
                    <Field
                        label="Notes"
                        value={notes}
                        onChange={lambda (value: str) { notes = value; }}
                        multiline={True}
                    />
                    <Pressable
                        style={styles.button}
                        disabled={busy or not title.strip()}
                        onPress={Add}
                        accessibilityRole="button"
                    >
                        <Text style={styles.buttonText}>
                            {"Saving..." if busy else "Save task"}
                        </Text>
                    </Pressable>
                </View>
                    if adding
                    else <View/>}
                <View style={styles.card}>
                    <Text style={styles.label}>DAILY PLAN</Text>
                    <Text style={styles.heading}>{DisplayDate(selectedDate)}</Text>
                    <Field
                        label="Choose date (YYYY-MM-DD)"
                        value={selectedDate}
                        onChange={lambda (value: str) { selectedDate = value; }}
                    />
                    <Pressable
                        style={styles.secondary}
                        onPress={lambda { selectedDate = Today(); }}
                        accessibilityRole="button"
                    >
                        <Text style={styles.secondaryText}>Today</Text>
                    </Pressable>
                    <Text style={styles.metric}>{str(minutes)} minutes remaining</Text>
                    <Text style={styles.subtitle}>
                        {str(len(dayTasks))} tasks planned
                    </Text>
                </View>
                {<Text style={styles.subtitle}>
                    No tasks planned for this day. Add a task with this planned date to get started.
                </Text>
                    if not loading and len(dayTasks) == 0
                    else <View/>}
                {[
                    <View key={task.taskId} style={styles.card}>
                        <Text style={styles.label}>{task.title}</Text>
                        <Text style={styles.subtitle}>
                            {task.course or "Personal"} / {task.priority} priority
                        </Text>
                        <Text style={styles.subtitle}>
                            {str(task.estimateMinutes)} min / Due {DisplayDate(
                                task.dueDate
                            )}
                        </Text>
                        {<Text style={styles.notes}>{task.notes}</Text>
                            if task.notes
                            else <View/>}
                        <Pressable
                            style={styles.secondary
                                if task.completed
                                else styles.button}
                            disabled={busy or loading}
                            onPress={lambda { Toggle(task); }}
                            accessibilityRole="button"
                            accessibilityLabel={"Reopen " + task.title
                                if task.completed
                                else "Complete " + task.title}
                        >
                            <Text
                                style={styles.secondaryText
                                    if task.completed
                                    else styles.buttonText}
                            >
                                {"Completed / Reopen"
                                    if task.completed
                                    else "Mark complete"}
                            </Text>
                        </Pressable>
                    </View> for task in dayTasks
                ]}
            </ScrollView>
        </KeyboardAvoidingView>;
}

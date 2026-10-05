import from react { useEffect }
import from "@jac/mobui" {
    View,
    Text,
    Pressable,
    TextInput,
    ScrollView,
    KeyboardAvoidingView,
    Keyboard,
    Platform,
    ActivityIndicator,
    useWindowDimensions
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

def ShiftDate(value: str, offset: int) -> str {
    date = new(Date, value + "T12:00:00");
    date.setDate(date.getDate() + offset);

    return str(date.getFullYear())
        + "-"
        + str(date.getMonth() + 1).zfill(2)
        + "-"
        + str(date.getDate()).zfill(2);
}

def CourseColor(course: str) -> str {
    total = 0;

    for index in range(len(course)) {
        total += ord(course[index]);
    }

    return ["#0066FF", "#9B45F5", "#6BA85D", "#F17649"][total % 4];
}

def TimeMinutes(value: str) -> int {
    parts = value.split(":");

    return int(parts[0]) * 60 + int(parts[1]);
}

def TimeLabel(minutes: int) -> str {
    hour = int(minutes / 60) % 24;
    minute = minutes % 60;

    return str(hour % 12 or 12)
        + (":" + str(minute).zfill(2) if minute else "")
        + (" AM" if hour < 12 else " PM");
}

def CurrentMinutes -> int {
    now = new(Date);

    return int(now.getHours() * 60 + now.getMinutes());
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
        notes: str = "",
        plannedTime: str = "",
        recurrence: str = "none",
        editingId: str = "",
        tab: str = "Calendar",
        trayOpen: bool = False,
        nowMinute: int = CurrentMinutes();

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
                editingId,
                title,
                course,
                dueDate,
                priority,
                int(estimate),
                plannedDate,
                notes,
                plannedTime,
                recurrence
            );

            if result.ok {
                title = "";
                course = "";
                dueDate = "";
                notes = "";
                recurrence = "none";
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

    def Edit(task: TaskView) {
        editingId = task.taskId;
        title = task.title;
        course = task.course;
        dueDate = task.dueDate;
        priority = task.priority;
        estimate = str(task.estimateMinutes);
        plannedDate = task.plannedDate;
        plannedTime = task.plannedTime;
        recurrence = task.recurrence;
        notes = task.notes;
        adding = True;
        error = "";
    }

    def TaskCard(task: TaskView) -> JsxElement {
        return
            <View
                key={task.taskId}
                style={[styles.taskCard, {"borderLeftColor": CourseColor(task.course)}]}
            >
                <Pressable
                    onPress={lambda { Edit(task); }}
                    accessibilityRole="button"
                    accessibilityLabel={"Edit " + task.title}
                >
                    <Text style={styles.taskTitle}>{task.title}</Text>
                    <Text style={{"color": CourseColor(task.course), "fontSize": 13}}>
                        {task.course or "Personal"}
                    </Text>
                    <Text style={styles.detail}>
                        {str(task.estimateMinutes)} min · {TimeLabel(
                            TimeMinutes(task.plannedTime)
                        )
                            if task.plannedTime
                            else "No time"} · Due {DisplayDate(task.dueDate)}
                    </Text>
                    {<Text style={styles.detail}>
                        {"Repeats daily" if task.recurrence == "daily" else "Repeats weekly"}
                    </Text>
                        if task.recurrence != "none"
                        else <View/>}
                </Pressable>
                <Pressable
                    disabled={busy}
                    onPress={lambda { Toggle(task); }}
                    accessibilityRole="button"
                    accessibilityLabel={"Reopen " + task.title
                        if task.completed
                        else "Complete " + task.title}
                >
                    <Text style={styles.secondaryText}>
                        {"✓ Completed · Reopen"
                            if task.completed
                            else "○ Mark complete"}
                    </Text>
                </Pressable>
            </View>;
    }

    async can with entry {
        await Refresh();
    }

    dayTasks = [
        task
        for task in tasks
        if task.plannedDate == selectedDate
    ];
    untimed = [
        task
        for task in dayTasks
        if not task.plannedTime
    ];
    unscheduled = [
        task
        for task in tasks
        if not task.plannedDate
    ];
    timed = [
        task
        for task in dayTasks
        if task.plannedTime
    ];
    deadlines = [
        task
        for task in tasks
        if task.dueDate
            and not task.completed
            and task.dueDate >= selectedDate
            and task.dueDate <= ShiftDate(selectedDate, 1)
    ];
    date = new(Date, selectedDate + "T12:00:00");
    weekStart = ShiftDate(selectedDate, -int((date.getDay() + 6) % 7));
    windowSize = useWindowDimensions();
    useEffect(
        lambda {
            timer = globalThis.setInterval(
                lambda { nowMinute = CurrentMinutes(); }, 30000
            );
            return lambda { globalThis.clearInterval(timer); };
        },
        []
    );
    firstHour = 9;
    lastHour = 17;

    for task in timed {
        firstHour = min(firstHour, int(TimeMinutes(task.plannedTime) / 60));
        lastHour = max(
            lastHour,
            int((TimeMinutes(task.plannedTime) + task.estimateMinutes + 59) / 60)
        );
    }

    timed = sorted(timed, key=lambda (task: TaskView) { return task.plannedTime; });
    blocks = [];
    laneEnds = [];

    for task in timed {
        minute = TimeMinutes(task.plannedTime);
        lane = 0;

        while lane < len(laneEnds) and laneEnds[lane] > minute {
            lane += 1;
        }

        if lane == len(laneEnds) {
            laneEnds.append(minute + max(task.estimateMinutes, 48));
        } else {
            laneEnds[lane] = minute + max(task.estimateMinutes, 48);
        }

        blocks.append({"task": task, "lane": lane, "minute": minute});
    }

    laneCount = max(1, len(laneEnds));

    return
        <KeyboardAvoidingView
            style={[
                styles.screen,
                {"height": windowSize.height} if Platform.OS == "web" else {}
            ]}
            behavior={"padding" if Platform.OS == "ios" else "height"}
        >
            <View style={styles.header}>
                <View style={styles.headerRow}>
                    <View>
                        <Text style={styles.heading}>
                            {"My tasks"
                                if tab == "Tasks"
                                else "Today"
                                    if selectedDate == Today()
                                    else "Daily plan"}
                        </Text>
                        <Text style={styles.subtitle}>
                            {date.toLocaleDateString(
                                "en-US",
                                {"weekday": "short", "month": "short", "day": "numeric"}
                            )}
                        </Text>
                    </View>
                    <Pressable
                        accessibilityRole="button"
                        accessibilityLabel="Add task"
                        onPress={lambda {
                            editingId = "";
                            title = "";
                            course = "";
                            dueDate = "";
                            notes = "";
                            estimate = "30";
                            plannedDate = selectedDate;
                            plannedTime = "";
                            recurrence = "none";
                            adding = not adding;
                            error = "";
                        }}
                    >
                        <Text style={styles.add}>＋</Text>
                    </Pressable>
                </View>
                <View style={styles.week}>
                    {[
                        <Pressable
                            key={str(index)}
                            style={styles.day}
                            accessibilityRole="button"
                            accessibilityLabel={DisplayDate(
                                ShiftDate(weekStart, index)
                            )}
                            accessibilityState={{
                                "selected": ShiftDate(weekStart, index) == selectedDate
                            }}
                            onPress={lambda { selectedDate = ShiftDate(
                                weekStart, index
                            ); }}
                        >
                            <Text style={styles.detail}>
                                {["Mon", "Tue", "Wed", "Thu", "Fri", "Sat", "Sun"][
                                    index
                                ]}
                            </Text>
                            <Text
                                style={styles.selectedDay
                                    if ShiftDate(weekStart, index) == selectedDate
                                    else styles.dayNumber}
                            >
                                {str(int(ShiftDate(weekStart, index).split("-")[2]))}
                            </Text>
                        </Pressable> for index in range(7)
                    ]}
                </View>
                <View style={styles.headerRow}>
                    <Pressable
                        onPress={lambda { selectedDate = ShiftDate(selectedDate, -7); }}
                        accessibilityLabel="Previous week"
                    >
                        <Text style={styles.secondaryText}>‹ Week</Text>
                    </Pressable>
                    <Pressable onPress={lambda { selectedDate = Today(); }}>
                        <Text style={styles.secondaryText}>Today</Text>
                    </Pressable>
                    <Pressable onPress={Refresh} disabled={loading or busy}>
                        <Text style={styles.secondaryText}>Refresh</Text>
                    </Pressable>
                    <Pressable
                        onPress={lambda { selectedDate = ShiftDate(selectedDate, 7); }}
                        accessibilityLabel="Next week"
                    >
                        <Text style={styles.secondaryText}>Week ›</Text>
                    </Pressable>
                </View>
            </View>
            <ScrollView
                style={styles.scroll}
                contentContainerStyle={styles.body}
                keyboardShouldPersistTaps="handled"
            >
                {<Text style={styles.error} accessibilityRole="alert">{error}</Text>
                    if error
                    else <View/>}{<ActivityIndicator color="#0066FF"/>
                    if loading or busy
                    else <View/>}{<View style={styles.card}>
                    <Text style={styles.label}>
                        {"Edit task" if editingId else "New task"}
                    </Text>
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
                        label="Planned time (HH:MM, optional)"
                        value={plannedTime}
                        onChange={lambda (value: str) { plannedTime = value; }}
                        placeholder="14:00"
                    />
                    <Text style={styles.label}>Repeat</Text>
                    <View style={styles.row}>
                        {[
                            <Pressable
                                key={interval}
                                style={styles.button
                                    if interval == recurrence
                                    else styles.secondary}
                                disabled={busy}
                                accessibilityRole="button"
                                accessibilityLabel={"Do not repeat"
                                    if interval == "none"
                                    else "Repeat " + interval}
                                accessibilityState={{"selected": interval == recurrence}}
                                onPress={lambda { recurrence = interval; }}
                            >
                                <Text
                                    style={styles.buttonText
                                        if interval == recurrence
                                        else styles.secondaryText}
                                >
                                    {"None" if interval == "none"
                                        else "Daily" if interval == "daily"
                                        else "Weekly"}
                                </Text>
                            </Pressable> for interval in ["none", "daily", "weekly"]
                        ]}
                    </View>
                    {<Text style={styles.detail}>
                        Completing this task adds the next occurrence.
                    </Text>
                        if recurrence != "none"
                        else <View/>}
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
                    else <View/>}{<View style={styles.banner}>
                    <Text style={styles.label}>
                        {str(len(deadlines))} {"deadline"
                            if len(deadlines) == 1
                            else "deadlines"} today or tomorrow
                    </Text>
                    <Text style={styles.detail}>
                        {deadlines[0].title} · {DisplayDate(deadlines[0].dueDate)}
                    </Text>
                </View>
                    if len(deadlines)
                    else <View/>}{<View style={{"gap": 10}}>
                    {<Text style={styles.label}>All day / No time</Text>
                        if len(untimed)
                        else <View/>}
                    {[TaskCard(task) for task in untimed]}
                    <View
                        style={{
                            "height": (lastHour - firstHour) * 72 + 20,
                            "position": "relative"
                        }}
                    >
                        {[
                            <View
                                key={str(hour)}
                                style={{
                                    "position": "absolute",
                                    "top": (hour - firstHour) * 72,
                                    "left": 0,
                                    "right": 0,
                                    "flexDirection": "row",
                                    "alignItems": "center"
                                }}
                            >
                                <Text style={styles.hour}>{TimeLabel(hour * 60)}</Text>
                                <View style={styles.rule}/>
                            </View> for hour in range(firstHour, lastHour + 1)
                        ]}{[
                            <Pressable
                                key={block["task"].taskId}
                                onPress={lambda { Edit(block["task"]); }}
                                accessibilityRole="button"
                                accessibilityLabel={"Edit " + block["task"].title}
                                style={[
                                    styles.timelineTask,
                                    {
                                        "top": (block["minute"] - firstHour * 60) * 1.2,
                                        "left": str(16 + block["lane"] * 84 / laneCount)
                                            + "%",
                                        "width": str(84 / laneCount - 1) + "%",
                                        "height": max(
                                            52, block["task"].estimateMinutes * 1.2 - 2
                                        ),
                                        "borderLeftColor": CourseColor(
                                            block["task"].course
                                        ),
                                        "opacity": 0.55
                                            if block["task"].completed
                                            else 1
                                    }
                                ]}
                            >
                                <Text numberOfLines={1} style={styles.taskTitle}>
                                    {block["task"].title}
                                </Text>
                                <Text
                                    numberOfLines={1}
                                    style={{
                                        "color": CourseColor(block["task"].course),
                                        "fontSize": 12,
                                        "lineHeight": 18
                                    }}
                                >
                                    {block["task"].course or "Personal"}{" · "
                                        + TimeLabel(block["minute"])
                                        if block["task"].estimateMinutes <= 45
                                        else ""}{" · " + block["task"].recurrence
                                        if block["task"].recurrence != "none"
                                        else ""}
                                </Text>
                                {<Text numberOfLines={1} style={styles.detail}>
                                    {TimeLabel(block["minute"])} – {TimeLabel(
                                        block["minute"] + block["task"].estimateMinutes
                                    )}
                                </Text>
                                    if block["task"].estimateMinutes > 45
                                    else <View/>}
                            </Pressable> for block in blocks
                        ]}{<View
                            pointerEvents="none"
                            style={{
                                "position": "absolute",
                                "top": (nowMinute - firstHour * 60) * 1.2,
                                "left": 0,
                                "right": 0,
                                "flexDirection": "row",
                                "alignItems": "center"
                            }}
                        >
                            <Text style={styles.nowLabel}>{TimeLabel(nowMinute)}</Text>
                            <View style={styles.nowRule}/>
                        </View>
                            if selectedDate == Today()
                                and nowMinute >= firstHour * 60
                                and nowMinute <= lastHour * 60
                            else <View/>}
                    </View>
                </View>
                    if tab == "Calendar"
                    else <View style={{"gap": 12}}>
                        <Text style={styles.label}>All tasks · {str(len(tasks))}</Text>
                        {[TaskCard(task) for task in tasks]}
                        {<Text style={styles.subtitle}>
                            Add your first task with +.
                        </Text>
                            if not len(tasks)
                            else <View/>}
                    </View>}
            </ScrollView>
            <View style={styles.tray}>
                <Pressable
                    accessibilityRole="button"
                    accessibilityState={{"expanded": trayOpen}}
                    onPress={lambda { trayOpen = not trayOpen; }}
                >
                    <Text style={styles.label}>
                        ☷  Unscheduled · {str(len(unscheduled))} {"⌄"
                            if trayOpen
                            else "⌃"}
                    </Text>
                </Pressable>
                {<ScrollView
                    style={{"maxHeight": 210}}
                    contentContainerStyle={{"gap": 8, "paddingTop": 12}}
                >
                    {[TaskCard(task) for task in unscheduled]}{<Text
                        style={styles.detail}
                    >
                        Every task has a planned day.
                    </Text>
                        if not len(unscheduled)
                        else <View/>}
                </ScrollView>
                    if trayOpen
                    else <View/>}
            </View>
            <View style={styles.tabs}>
                {[
                    <Pressable
                        key={name}
                        style={styles.tab}
                        accessibilityRole="tab"
                        accessibilityState={{"selected": tab == name}}
                        onPress={lambda { tab = name; }}
                    >
                        <Text style={styles.tabIcon}>
                            {"▦" if name == "Calendar" else "☑"}
                        </Text>
                        <Text
                            style={styles.secondaryText
                                if tab == name
                                else styles.detail}
                        >
                            {name}
                        </Text>
                    </Pressable> for name in ["Calendar", "Tasks"]
                ]}
            </View>
        </KeyboardAvoidingView>;
}

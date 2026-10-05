import from pathlib { Path }
import from tempfile { TemporaryDirectory }
import from jaclang.testing.testing { JacTestClient }

glob SERVER = str(Path(__file__).with_name("planner.jac"));

test "tasks persist and support the full editing lifecycle" {
    with TemporaryDirectory() as storePath {
        client = JacTestClient.from_file(SERVER, base_path=storePath);
        try {
            assert client.post("/function/ListTasks", json={}).data["result"]["tasks"]
                == [];
            added = client.post(
                "/function/SaveTask",
                json={
                    "title": "  Homework 1  ",
                    "course": "EECS 449",
                    "dueDate": "2026-10-02",
                    "plannedDate": "2026-09-30",
                    "priority": "high",
                    "estimateMinutes": 90,
                    "notes": "Read chapter 2"
                }
            );
            assert added.ok , added.data;
            result = added.data["result"];
            assert result["ok"] , result;
            taskId = result["task"]["taskId"];
            assert taskId and result["task"]["title"] == "Homework 1";
            done = client.post(
                "/function/SetCompleted", json={"taskId": taskId, "completed": True}
            );
            assert done.data["result"]["task"]["completed"];
            edited = client.post(
                "/function/SaveTask",
                json={"taskId": taskId, "title": "Revised", "estimateMinutes": 1}
            );
            assert edited.data["result"]["task"]["completed"];
            assert edited.data["result"]["task"]["dueDate"] == "";
        } finally {
            client.close();
        }
        client = JacTestClient.from_file(SERVER, base_path=storePath);
        try {
            stored = client.post("/function/ListTasks", json={}).data["result"][
                "tasks"
            ];
            assert len(stored) == 1;
            assert stored[0]["taskId"] == taskId;
            assert stored[0]["title"] == "Revised" and stored[0]["completed"];
            reopened = client.post(
                "/function/SetCompleted", json={"taskId": taskId, "completed": False}
            );
            assert not reopened.data["result"]["task"]["completed"];
            deleted = client.post("/function/DeleteTask", json={"taskId": taskId});
            assert deleted.data["result"]["ok"];
            assert client.post("/function/ListTasks", json={}).data["result"]["tasks"]
                == [];
            assert not client.post("/function/DeleteTask", json={"taskId": taskId}).data[
                "result"
            ]["ok"];
        } finally {
            client.close();
        }
    }
}

test "invalid requests cannot create or change tasks" {
    with TemporaryDirectory() as storePath {
        client = JacTestClient.from_file(SERVER, base_path=storePath);
        try {
            payloads: list[dict[str, str | int]] = [
                {"title": " "},
                {"title": "Bad", "priority": "urgent"},
                {"title": "Bad", "estimateMinutes": 0},
                {"title": "Bad", "estimateMinutes": 1441},
                {"title": "Bad", "dueDate": "2026-02-29"},
                {"title": "Bad", "plannedDate": "20260930"},
                {"title": "Bad", "dueDate": "2026-9-30"},
                {"title": "Bad", "taskId": "unknown"}
            ];

            for payload in payloads {
                response = client.post("/function/SaveTask", json=payload);
                assert response.ok , f"{payload}: {response.data}";
                assert not response.data["result"]["ok"] , payload;
                assert response.data["result"]["error"];
                assert response.data["result"]["task"] is None;
            }
            assert client.post("/function/ListTasks", json={}).data["result"]["tasks"]
                == [];
            assert not client.post(
                "/function/SetCompleted", json={"taskId": "unknown", "completed": True}
            ).data["result"]["ok"];
            valid = client.post(
                "/function/SaveTask",
                json={
                    "title": "Leap day",
                    "dueDate": "2028-02-29",
                    "estimateMinutes": 1440
                }
            );
            assert valid.data["result"]["ok"];
            taskId = valid.data["result"]["task"]["taskId"];
            invalid = client.post(
                "/function/SaveTask",
                json={"taskId": taskId, "title": "Replacement", "priority": "bad"}
            );
            assert not invalid.data["result"]["ok"];
            stored = client.post("/function/ListTasks", json={}).data["result"][
                "tasks"
            ];
            assert stored[0]["title"] == "Leap day";
        } finally {
            client.close();
        }
    }
}

test "malformed transport parameters leave existing task data intact" {
    with TemporaryDirectory() as storePath {
        client = JacTestClient.from_file(SERVER, base_path=storePath);
        try {
            saved = client.post("/function/SaveTask", json={"title": "Original"});
            taskId = saved.data["result"]["task"]["taskId"];
            badEstimate = client.post(
                "/function/SaveTask",
                json={
                    "taskId": taskId,
                    "title": "Replacement",
                    "estimateMinutes": "invalid"
                }
            );
            assert badEstimate.status_code == 422;
            badCompletion = client.post(
                "/function/SetCompleted",
                json={"taskId": taskId, "completed": "invalid"}
            );
            assert badCompletion.status_code == 422;
            missingCompletion = client.post(
                "/function/SetCompleted", json={"taskId": taskId}
            );
            assert missingCompletion.status_code == 422;
            nullDate = client.post(
                "/function/SaveTask",
                json={"taskId": taskId, "title": "Replacement", "dueDate": None}
            );
            assert not nullDate.data["result"]["ok"];
            tasks = client.post("/function/ListTasks", json={}).data["result"]["tasks"];
            assert len(tasks) == 1;
            assert tasks[0]["title"] == "Original";
            assert tasks[0]["estimateMinutes"] == 30;
            assert not tasks[0]["completed"];
        } finally {
            client.close();
        }
    }
}

test "time blocks validate and persist without losing legacy edits" {
    with TemporaryDirectory() as storePath {
        client = JacTestClient.from_file(SERVER, base_path=storePath);
        try {
            invalidTimes = ["9:00", "24:00", "12:60", "12:00:00", "aa:bb", "１２:００"];

            for plannedTime in invalidTimes {
                result = client.post(
                    "/function/SaveTask",
                    json={
                        "title": "Invalid",
                        "plannedDate": "2026-09-30",
                        "plannedTime": plannedTime
                    }
                ).data["result"];
                assert not result["ok"];
            }
            assert not client.post(
                "/function/SaveTask", json={"title": "No day", "plannedTime": "09:00"}
            ).data["result"]["ok"];
            assert not client.post(
                "/function/SaveTask",
                json={
                    "title": "Too late",
                    "plannedDate": "2026-09-30",
                    "plannedTime": "23:31",
                    "estimateMinutes": 30
                }
            ).data["result"]["ok"];
            saved = client.post(
                "/function/SaveTask",
                json={
                    "title": "Midnight boundary",
                    "plannedDate": "2026-09-30",
                    "plannedTime": "23:30",
                    "estimateMinutes": 30
                }
            ).data["result"];
            assert saved["ok"];
            taskId = saved["task"]["taskId"];
            edited = client.post(
                "/function/SaveTask",
                json={
                    "taskId": taskId,
                    "title": "Legacy edit",
                    "plannedDate": "2026-09-30"
                }
            ).data["result"];
            assert edited["ok"] and edited["task"]["plannedTime"] == "23:30";
            rejected = client.post(
                "/function/ScheduleTask",
                json={
                    "taskId": taskId,
                    "plannedDate": "2026-10-01",
                    "plannedTime": "23:59"
                }
            ).data["result"];
            assert not rejected["ok"];
        } finally {
            client.close();
        }
        client = JacTestClient.from_file(SERVER, base_path=storePath);
        try {
            stored = client.post("/function/ListTasks", json={}).data["result"][
                "tasks"
            ];
            assert stored[0]["plannedTime"] == "23:30";
            assert stored[0]["plannedDate"] == "2026-09-30";
            unscheduled = client.post(
                "/function/ScheduleTask", json={"taskId": taskId}
            ).data["result"];
            assert unscheduled["ok"];
            assert unscheduled["task"]["plannedDate"] == "";
            assert unscheduled["task"]["plannedTime"] == "";
            timed = client.post(
                "/function/ScheduleTask",
                json={
                    "taskId": taskId,
                    "plannedDate": "2026-10-01",
                    "plannedTime": "09:00"
                }
            ).data["result"];
            assert timed["ok"] and timed["task"]["title"] == "Legacy edit";
            cleared = client.post(
                "/function/SaveTask", json={"taskId": taskId, "title": "Cleared"}
            ).data["result"];
            assert cleared["ok"] and cleared["task"]["plannedTime"] == "";
        } finally {
            client.close();
        }
    }
}

test "recurrence advances calendar dates and copies task details" {
    with TemporaryDirectory() as storePath {
        client = JacTestClient.from_file(SERVER, base_path=storePath);

        try {
            cases = [
                ("daily", "2026-01-31", "2026-02-01", "2026-12-31", "2027-01-01"),
                ("daily", "2028-02-28", "2028-02-29", "2028-02-29", "2028-03-01"),
                ("weekly", "2026-12-28", "2027-01-04", "2028-02-25", "2028-03-03"),
                ("daily", "2026-02-28", "2026-03-01", "", ""),
                ("weekly", "", "", "2026-10-01", "2026-10-08")
            ];

            for (recurrence, due, nextDue, planned, nextPlanned) in cases {
                saved = client.post(
                    "/function/SaveTask",
                    json={
                        "title": "Practice",
                        "course": "EECS 449",
                        "priority": "high",
                        "estimateMinutes": 45,
                        "notes": "Review",
                        "dueDate": due,
                        "plannedDate": planned,
                        "plannedTime": "09:30" if planned else "",
                        "recurrence": recurrence
                    }
                ).data["result"];
                assert saved["ok"] , saved;
                taskId = saved["task"]["taskId"];
                done = client.post(
                    "/function/SetCompleted", json={"taskId": taskId, "completed": True}
                ).data["result"];
                assert done["ok"] and done["task"]["completed"];
                tasks = client.post("/function/ListTasks", json={}).data["result"]["tasks"];
                following = [task for task in tasks if not task["completed"]];
                assert len(following) == 1;
                successor = following[0];
                assert successor["dueDate"] == nextDue;
                assert successor["plannedDate"] == nextPlanned;

                for field in ["title", "course", "priority", "estimateMinutes", "notes", "plannedTime", "recurrence"] {
                    assert successor[field] == saved["task"][field];
                }

                for task in tasks {
                    client.post("/function/DeleteTask", json={"taskId": task["taskId"]});
                }
            }
        } finally {
            client.close();
        }
    }
}

test "recurrence generates only once even after reopening deleting and restarting" {
    with TemporaryDirectory() as storePath {
        client = JacTestClient.from_file(SERVER, base_path=storePath);

        try {
            saved = client.post(
                "/function/SaveTask", json={"title": "Daily", "recurrence": "daily"}
            ).data["result"];
            taskId = saved["task"]["taskId"];
            client.post("/function/SetCompleted", json={"taskId": taskId, "completed": True});
            client.post("/function/SetCompleted", json={"taskId": taskId, "completed": True});
            tasks = client.post("/function/ListTasks", json={}).data["result"]["tasks"];
            assert len(tasks) == 2;
            successor = [task for task in tasks if task["taskId"] != taskId][0];
            assert successor["dueDate"] == (date.today() + timedelta(days=1)).isoformat();
            assert successor["plannedDate"] == "";
            client.post("/function/SetCompleted", json={"taskId": taskId, "completed": False});
            client.post("/function/SetCompleted", json={"taskId": taskId, "completed": True});
            assert len(client.post("/function/ListTasks", json={}).data["result"]["tasks"]) == 2;
            client.post("/function/DeleteTask", json={"taskId": successor["taskId"]});
        } finally {
            client.close();
        }
        client = JacTestClient.from_file(SERVER, base_path=storePath);

        try {
            client.post("/function/SetCompleted", json={"taskId": taskId, "completed": False});
            client.post("/function/SetCompleted", json={"taskId": taskId, "completed": True});
            assert len(client.post("/function/ListTasks", json={}).data["result"]["tasks"]) == 1;
        } finally {
            client.close();
        }
    }
}

test "recurrence edits preserve legacy defaults and reject invalid or overflowing dates" {
    with TemporaryDirectory() as storePath {
        client = JacTestClient.from_file(SERVER, base_path=storePath);

        try {
            plain = client.post("/function/SaveTask", json={"title": "Plain"}).data["result"];
            taskId = plain["task"]["taskId"];
            assert plain["task"]["recurrence"] == "none";
            client.post("/function/SetCompleted", json={"taskId": taskId, "completed": True});
            assert len(client.post("/function/ListTasks", json={}).data["result"]["tasks"]) == 1;
            recurring = client.post(
                "/function/SaveTask", json={"title": "Weekly", "recurrence": "weekly"}
            ).data["result"];
            repeatId = recurring["task"]["taskId"];

            for payload in [
                {"taskId": repeatId, "title": "Edited"},
                {"taskId": repeatId, "title": "Edited", "recurrence": "None"}
            ] {
                edited = client.post("/function/SaveTask", json=payload).data["result"];
                assert edited["ok"] and edited["task"]["recurrence"] == "weekly";
            }
            invalid = client.post(
                "/function/SaveTask", json={"taskId": repeatId, "title": "Bad", "recurrence": "monthly"}
            ).data["result"];
            assert not invalid["ok"];
            cleared = client.post(
                "/function/SaveTask", json={"taskId": repeatId, "title": "Cleared", "recurrence": "none"}
            ).data["result"];
            assert cleared["ok"] and cleared["task"]["recurrence"] == "none";
            client.post("/function/SetCompleted", json={"taskId": repeatId, "completed": True});
            assert len(client.post("/function/ListTasks", json={}).data["result"]["tasks"]) == 2;

            for field in ["dueDate", "plannedDate"] {
                saved = client.post(
                    "/function/SaveTask", json={"title": "Overflow", "recurrence": "daily", field: "9999-12-31"}
                ).data["result"];
                overflowId = saved["task"]["taskId"];
                rejected = client.post(
                    "/function/SetCompleted", json={"taskId": overflowId, "completed": True}
                ).data["result"];
                assert not rejected["ok"];
                tasks = client.post("/function/ListTasks", json={}).data["result"]["tasks"];
                original = [task for task in tasks if task["taskId"] == overflowId][0];
                assert not original["completed"];
                assert original[field] == "9999-12-31";
                client.post("/function/DeleteTask", json={"taskId": overflowId});
            }
            assert len(client.post("/function/ListTasks", json={}).data["result"]["tasks"]) == 2;
        } finally {
            client.close();
        }
    }
}

test "older task nodes expose default recurrence" {
    task = Task(title="Legacy");
    delattr(task, "recurrence");
    delattr(task, "successorGenerated");
    assert task.ToView().recurrence == "none";
}

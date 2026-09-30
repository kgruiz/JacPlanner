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

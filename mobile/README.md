# Native mobile app

The mobile daily plan uses the same planner service and graph database as the browser and CLI. Its native Calendar tab shows a daily hour timeline, a seven-day date strip, upcoming deadlines, and an expandable unscheduled tray. The Tasks tab supports editing, completing, and reopening every task. Dates are entered as `YYYY-MM-DD` and displayed as `MM/DD/YYYY`.

## Prerequisites

Install Xcode with an iOS simulator runtime, CocoaPods, and Node.js. Jac generates an Expo/React Native project in ignored `.jac/mobile-rn/`; generated code and build products should stay out of Git.

From the repository root, keep the shared server running:

```sh
jac run --port 8000
```

In a second terminal, generate the native app using Node for Expo:

```sh
jac setup mobile
JAC_BUN="$(command -v node)" jac build --platform ios mobile
python3 mobile/configure-api.py http://127.0.0.1:8000
```

Run setup with Jac's default Bun first so dependencies are installed. The `JAC_BUN` override then avoids a Bun/Expo prebuild issue observed locally where the generated Xcode project contains trailing NUL bytes. Jac also invokes Xcode after generating the project; in an iCloud-synced Documents directory this can fail at signing with a resource fork/Finder metadata error. If generation and CocoaPods installation completed, continue with the unsigned simulator build below. The configuration helper sets Expo's supported `extra.apiBaseUrl` value and the imported `__jacApiBase.js` runtime value, so it also works when the native manifest was compiled before configuration. Run it again after regenerating the native project, because Jac can replace these files. The simulator can access the Mac's loopback address.

Build into a directory outside iCloud-synced Documents to avoid Finder metadata errors during framework signing:

```sh
xcrun simctl list devices available
xcodebuild -workspace .jac/mobile-rn/ios/main.xcworkspace \
  -scheme main -configuration Debug -sdk iphonesimulator \
  -destination 'platform=iOS Simulator,name=iPhone 17 Pro,OS=26.5' \
  -derivedDataPath /tmp/jacplanner-ios-derived CODE_SIGNING_ALLOWED=NO
```

Start Metro in a third terminal and leave it running:

```sh
cd .jac/mobile-rn
node node_modules/expo/bin/cli start --localhost --port 8081
```

Open Xcode's Device Hub, choose the iPhone simulator, and start it. With exactly one simulator booted, install and launch the built app from the repository root:

```sh
xcrun simctl install booted /tmp/jacplanner-ios-derived/Build/Products/Debug-iphonesimulator/main.app
xcrun simctl launch booted com.jac.app
```

Use an iOS 26 simulator listed on your Mac if `iPhone 17 Pro,OS=26.5` is unavailable. The current Expo template crashes on iOS 27 because it does not adopt the required scene lifecycle. Native launch and shared server reads were verified on iPhone 17 Pro with iOS 26.5. Current Xcode installations can place Device Hub at `/Applications/Xcode.app/Contents/Applications/DeviceHub.app`.

## Controls

- **+** opens a new task form. Tap a timeline block or task title to edit all fields.
- **Calendar** shows the selected day's timed blocks and an **All day / No time** section for dated tasks without a time. Overlapping tasks occupy separate columns. The timeline expands for early and late tasks.
- The date strip selects a day. **Week** arrows move backward or forward seven days; **Today** returns to the current local date.
- **Planned date** uses `YYYY-MM-DD`; optional **Planned time** uses 24-hour `HH:MM`. A time requires a date. Estimates determine block duration; the server rejects blocks ending after midnight. Clear the time to make a dated task untimed, or clear both fields to unschedule it.
- **Tasks** lists every task with **Mark complete** and **Completed / Reopen** controls. Task titles open the editor.
- **Unscheduled** expands above the tabs to show tasks without a planned day. Tap a title to schedule it.
- **Refresh** reloads changes from the browser or CLI. Errors retain the form draft so it can be retried.

Course colors use the same deterministic character-sum palette as the web view. Deadline notices use open tasks due on the selected day or the following day. The red current-time line appears only on today's calendar and updates every 30 seconds.

If the server is unavailable, the app displays an error and allows refreshing. This app requires the local server and does not maintain an offline copy of tasks. Task deletion is available on the web dashboard.

Unsigned simulator builds can show Expo SecureStore entitlement warnings. Public local planner endpoints do not require an authentication token. Device Hub UI automation timed out during verification, so native task entry and completion interactions still need a manual simulator check.

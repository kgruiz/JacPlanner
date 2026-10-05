# Native mobile app

The mobile app gives you a daily view of the same tasks you see on the web and in the CLI. You can switch days from the date strip, schedule something from the unscheduled tray, or open the Tasks tab to edit and complete assignments.

## Prerequisites

Install Xcode with the iOS 26.5 simulator runtime, CocoaPods, and Node.js. Jac generates the Expo/React Native project in `.jac/mobile-rn/`, which is excluded from Git.

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

Setup uses Jac's default Bun to install dependencies, but the build command switches to Node because Bun produced an invalid Xcode project during local setup. Jac also tries to build the native app at this point. If project generation and CocoaPods installation finish but signing fails with a resource fork or Finder metadata error, you can continue with the unsigned build below.

The last command tells the mobile app where to find the server. The simulator can reach your Mac at `127.0.0.1`, so it uses the same address as the browser. Run `configure-api.py` again if you regenerate the project, since generation can replace that setting.

Build into a directory outside iCloud-synced Documents to avoid Finder metadata errors during framework signing:

```sh
xcrun simctl list devices available
xcodebuild -workspace .jac/mobile-rn/ios/main.xcworkspace \
  -scheme main -configuration Debug -sdk iphonesimulator \
  -destination 'platform=iOS Simulator,name=iPhone 17 Pro,OS=26.5' \
  -derivedDataPath /tmp/jacplanner-ios-derived CODE_SIGNING_ALLOWED=NO
```

Start Metro, which serves the app's JavaScript, in a third terminal and leave it running:

```sh
cd .jac/mobile-rn
node node_modules/expo/bin/cli start --localhost --port 8081
```

Open Xcode's Device Hub and start **iPhone 17 Pro with iOS 26.5**. Check `xcrun simctl list devices booted` before continuing: the build destination above does not select the device used by `booted`. With only the iOS 26.5 simulator running, install and launch the app from the repository root:

```sh
xcrun simctl install booted /tmp/jacplanner-ios-derived/Build/Products/Debug-iphonesimulator/main.app
xcrun simctl launch booted com.jac.app
```

Use an iOS 26 simulator listed on your Mac if `iPhone 17 Pro,OS=26.5` is unavailable. The current Expo template crashes on iOS 27 because it does not adopt the required scene lifecycle. Current Xcode installations can place Device Hub at `/Applications/Xcode.app/Contents/Applications/DeviceHub.app`.

## Using the app

Tap **+** to add a task, or tap an existing title or calendar block to edit it. In the Tasks tab, you can mark an assignment complete and reopen it if you need to come back to it. Deleting tasks is available in the web app.

Choose **Daily** or **Weekly** under **Repeat** for work you do regularly. Completing it creates the next occurrence and keeps the completed one in your history. To stop repeating, edit the next open task and turn repetition off.

The Calendar tab shows the selected day's schedule, with an **All day / No time** section for tasks that have a date but no start time. Use the date strip to choose a day, the **Week** arrows to move between weeks, or **Today** to return to the current day. If tasks overlap, they appear side by side, and the timeline expands to fit early or late work.

Enter dates as `YYYY-MM-DD` and start times as 24-hour `HH:MM`; the app displays dates as `MM/DD/YYYY`. A task needs a planned date before you can give it a time, and its estimated minutes determine the length of the block. Blocks can't run past midnight. To keep a task on a day's plan without a specific time, clear its start time. Clear both fields to move it back to **Unscheduled**, which you can expand above the tabs.

Course colors match the web app, and deadline notices show unfinished work due on the selected day or the next day. On today's calendar, a red line marks the current time and updates every 30 seconds.

Use **Refresh** to pick up changes you've made in the browser or CLI. If a save fails, your draft stays in the form so you can try again. Keep the server running while you use the app, since tasks aren't available offline.

Unsigned builds may show Expo SecureStore entitlement warnings, though the local planner doesn't require a login.

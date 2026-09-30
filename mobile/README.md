# Native mobile app

The mobile daily plan uses the same planner service and graph database as the browser and CLI. It supports choosing a day, adding tasks with all task fields, completing tasks, and reopening completed tasks. Dates are entered as `YYYY-MM-DD` and displayed as `MM/DD/YYYY`.

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

- **Add task** opens the entry form. Set a planned date to include the task in that day's plan.
- **Choose date** filters the plan. **Today** returns to the current local day.
- **Mark complete** removes a task's estimate from remaining minutes. **Completed / Reopen** restores it.
- **Refresh** reloads server changes made in the browser or CLI.

If the server is unavailable, the app displays an error and allows refreshing. This app requires the local server; it does not maintain an offline copy of tasks. The native interface intentionally provides task creation and completion controls; full task editing and deletion are available on the web dashboard.

Unsigned simulator builds can show Expo SecureStore entitlement warnings. Public local planner endpoints do not require an authentication token. Device Hub UI automation timed out during verification, so native task entry and completion interactions still need a manual simulator check.

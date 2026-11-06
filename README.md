# Keep Awake

A small macOS menu-bar app that periodically moves the mouse by up to 60 points, pauses for half a second, and returns it to its original position. Turn it on when you need it; it starts off and has no login item or background service. Choose an interval of 5 seconds, 30 seconds, 1 minute, 2 minutes, or 5 minutes from the menu. Successive movements cycle left, right, up, and down. The 5-second interval is useful for testing. When you move the mouse, automatic movement pauses until the mouse has been still for 30 seconds. The menu shows the remaining countdown. The app skips movements while a mouse button is held, and skips the return if you move the pointer during its half-second pause.

## Build and run

Requires macOS 13 or later and Xcode or the Xcode Command Line Tools with Swift.

```sh
./scripts/build.sh
open "build/Keep Awake.app"
```

Click the cup icon in the menu bar and choose **Turn On**. The first time, macOS will ask for Accessibility permission. Enable **Keep Awake** under **System Settings → Privacy & Security → Accessibility**, then select **Turn On** again. If the app is missing from the list, add it using the `+` button. To install it, copy the built app to Applications before granting permission. Rebuilding or moving an ad-hoc-signed app may require granting permission again.

Choose **Turn Off** to stop moving the pointer, or **Quit Keep Awake** to exit. The interval resets to one minute when the app restarts. If Accessibility permission is revoked, the app turns itself off at its next scheduled movement.

## Test

Run `./scripts/test.sh` to check the movement and pause schedule.

## Limitations

Synthetic mouse activity may not reset every macOS or third-party idle timer. A managed device can still lock due to its configuration or security software; this app does not change management profiles or guarantee that a lock will be prevented. It cannot unlock a locked Mac, prevent manual locking or lid-close sleep, or keep working after the Mac sleeps. Moving the pointer may affect whatever is under it. Use it only where permitted by your organization's policies.

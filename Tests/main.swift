import Foundation

func check(_ condition: @autoclosure () -> Bool, _ description: String) {
    guard condition() else {
        fputs("FAIL: \(description)\n", stderr)
        exit(1)
    }
}

var schedule = MovementSchedule(interval: 5, now: 0)
check(!schedule.movementIsDue(at: 4.9), "wait for initial interval")
check(schedule.movementIsDue(at: 5), "first movement")
schedule.userMoved(at: 6)
check(schedule.pauseSecondsRemaining(at: 6) == 30, "user movement pauses for 30 seconds")
check(!schedule.movementIsDue(at: 35.9), "do not move during pause")
schedule.userMoved(at: 20)
check(schedule.pauseSecondsRemaining(at: 35) == 15, "more movement resets the countdown")
check(!schedule.movementIsDue(at: 49.9), "wait for the reset countdown")
check(schedule.movementIsDue(at: 50), "move as soon as the pause ends")
check(!schedule.movementIsDue(at: 54.9), "wait for the next interval")
check(schedule.movementIsDue(at: 55), "move again after the pause")
check(schedule.movementIsDue(at: 60), "keep moving at later intervals")
schedule.userMoved(at: 61)
schedule.changeInterval(120, at: 70)
check(!schedule.movementIsDue(at: 90), "changing interval preserves active pause")
check(schedule.movementIsDue(at: 91), "resume after interval changes while paused")
check(!schedule.movementIsDue(at: 210), "use the new interval after resuming")
check(schedule.movementIsDue(at: 211), "move again at the new interval")
print("Movement scheduling checks passed")

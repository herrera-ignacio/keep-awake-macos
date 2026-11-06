import Foundation

/// Schedules movements using a monotonic clock supplied by the caller.
struct MovementSchedule {
    private(set) var interval: TimeInterval
    private(set) var pausedUntil: TimeInterval?
    private(set) var nextMovement: TimeInterval
    let pauseDuration: TimeInterval

    init(interval: TimeInterval, now: TimeInterval, pauseDuration: TimeInterval = 30) {
        self.interval = interval
        self.pauseDuration = pauseDuration
        self.nextMovement = now + interval
    }

    mutating func userMoved(at now: TimeInterval) {
        pausedUntil = now + pauseDuration
        nextMovement = now + pauseDuration
    }

    mutating func changeInterval(_ interval: TimeInterval, at now: TimeInterval) {
        self.interval = interval
        if let pausedUntil, pausedUntil > now {
            nextMovement = pausedUntil
        } else {
            self.pausedUntil = nil
            nextMovement = now + interval
        }
    }

    func pauseSecondsRemaining(at now: TimeInterval) -> Int {
        guard let pausedUntil else { return 0 }
        return max(0, Int(ceil(pausedUntil - now)))
    }

    mutating func movementIsDue(at now: TimeInterval) -> Bool {
        guard now >= nextMovement else { return false }
        pausedUntil = nil
        nextMovement = now + interval
        return true
    }
}

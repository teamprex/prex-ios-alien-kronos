import Foundation

private let kUptimeKey = "Uptime"
private let kTimestampKey = "Timestamp"
private let kOffsetKey = "Offset"

struct TimeFreeze {
    private let uptime: TimeInterval
    private let timestamp: TimeInterval
    let offset: TimeInterval

    /// The stable timestamp adjusted by the most accurate offset known so far.
    var adjustedTimestamp: TimeInterval {
        return self.offset + self.stableTimestamp
    }

    /// The stable timestamp (calculated based on the uptime); note that this doesn't have sub-seconds
    /// precision. See `systemUptime()` for more information.
    var stableTimestamp: TimeInterval {
        return (TimeFreeze.systemUptime() - self.uptime) + self.timestamp
    }

    /// Time interval between now and the time the NTP response represented by this TimeFreeze was received.
    var timeSinceLastNtpSync: TimeInterval {
        return TimeFreeze.systemUptime() - uptime
    }

    init(offset: TimeInterval) {
        self.offset = offset
        self.timestamp = currentTime()
        self.uptime = TimeFreeze.systemUptime()
    }

    init?(from dictionary: [String: TimeInterval]) {
        guard let uptime = dictionary[kUptimeKey], let timestamp = dictionary[kTimestampKey],
            let offset = dictionary[kOffsetKey] else
        {
            return nil
        }

        let currentUptime = TimeFreeze.systemUptime()
        let currentTimestamp = currentTime()
        let currentBoot = currentUptime - currentTimestamp
        let previousBoot = uptime - timestamp
        if rint(currentBoot) - rint(previousBoot) != 0 {
            return nil
        }

        self.uptime = uptime
        self.timestamp = timestamp
        self.offset = offset
    }

    /// Convert this TimeFreeze to a dictionary representation.
    ///
    /// - returns: A dictionary representation.
    func toDictionary() -> [String: TimeInterval] {
        return [
            kUptimeKey: self.uptime,
            kTimestampKey: self.timestamp,
            kOffsetKey: self.offset
        ]
    }

    /// Returns a high-resolution measurement of system uptime, that continues ticking through device sleep
    /// *and* user- or system-generated clock adjustments. This allows for stable differences to be calculated
    /// between timestamps.
    ///
    /// Note: Due to an issue in BSD/darwin, sub-second precision will be lost;
    /// see: https://github.com/darwin-on-arm/xnu/blob/master/osfmk/kern/clock.c#L522.
    ///
    /// - returns: An Int measurement of system uptime in microseconds.
    static func systemUptime() -> TimeInterval {
        var mib = [CTL_KERN, KERN_BOOTTIME]
        var size = MemoryLayout<timeval>.stride
        var bootTime = timeval()

        let bootTimeError = sysctl(&mib, u_int(mib.count), &bootTime, &size, nil, 0) != 0
        assert(!bootTimeError, "system clock error: kernel boot time unavailable")

        let now = currentTime()
        let uptime: TimeInterval = Double(bootTime.tv_sec) + Double(bootTime.tv_usec) / 1_000_000
        assert(now >= uptime, "inconsistent clock state: system time precedes boot time")
        print("yktest systemUptime1: \(now - uptime)")

        _ = systemUptime2()
        _ = systemUptime3()

        return now - uptime
    }
    
    /// Returns a high-resolution measurement of system uptime, that continues ticking through device sleep
    /// *and* user- or system-generated clock adjustments. This allows for stable differences to be calculated
    /// between timestamps.
    ///
    /// - returns: An Int measurement of system uptime in nanoseconds.
    /// - reference: https://stackoverflow.com/a/45068046/23930754
    /// - Note: This function is thread-safe. Can be called from any thread concurrently.
//    static func systemUptime() -> TimeInterval {
//        var uptime = timespec()
//        /// Thread-safe reference: https://man7.org/linux/man-pages/man3/clock_gettime.3.html#ATTRIBUTES
//        if 0 != clock_gettime(CLOCK_MONOTONIC_RAW, &uptime) {
//            fatalError("Could not execute clock_gettime, errno: \(errno)")
//        }
//        let uptimeInNanoSeconds = UInt64(uptime.tv_sec * 1_000_000_000) + UInt64(uptime.tv_nsec)
//        let uptimeInSeconds = TimeInterval(uptimeInNanoSeconds) / TimeInterval(NSEC_PER_SEC)
//
//        return uptimeInSeconds
//    }

    static func systemUptime2() -> TimeInterval {
        var now: TimeInterval
        var beforeNow: Double
        var afterNow = bootTime()
        var i = 0
        repeat {
            beforeNow = afterNow
            now = currentTime()
            afterNow = bootTime()
            if i > 1 {
                print("yktest systemUptime2: loop \(i)")
            }
            i += 1
        } while (afterNow != beforeNow)

        print("yktest systemUptime2 beforeNow: \(beforeNow)")
        print("yktest systemUptime2 afterNow: \(afterNow)")
        print("yktest systemUptime2: \(now - beforeNow)")

        assert(now >= beforeNow, "inconsistent clock state: system time precedes boot time")

        return now - beforeNow
    }

    private static func bootTime() -> Double {
        var mib = [CTL_KERN, KERN_BOOTTIME]
        var size = MemoryLayout<timeval>.stride
        var bootTime = timeval()

        let bootTimeError = sysctl(&mib, u_int(mib.count), &bootTime, &size, nil, 0) != 0
        assert(!bootTimeError, "system clock error: kernel boot time unavailable")

        return Double(bootTime.tv_sec) + Double(bootTime.tv_usec) / 1_000_000
    }

    static func systemUptime3() -> TimeInterval {
        var uptime = timespec()
        if 0 != clock_gettime(CLOCK_MONOTONIC_RAW, &uptime) {
            fatalError("Could not execute clock_gettime, errno: \(errno)")
        }
        let uptimeInNanoSeconds = UInt64(uptime.tv_sec * 1_000_000_000) + UInt64(uptime.tv_nsec)
        let uptimeInSeconds = TimeInterval(uptimeInNanoSeconds) / TimeInterval(NSEC_PER_SEC)
        print("yktest systemUptime3: \(uptimeInSeconds)")
        return uptimeInSeconds
    }
}

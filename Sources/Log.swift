import Foundation

public enum Log {
    case unmatchedUserDefaultsValue(value: String)
    case dictionaryValueNotFound(dictionary: [String: TimeInterval])
    case invalidBootTime(currentUptime: TimeInterval, currentTimestamp: TimeInterval, currentBoot: TimeInterval, previousBoot: TimeInterval, dictionary: [String: TimeInterval])
}

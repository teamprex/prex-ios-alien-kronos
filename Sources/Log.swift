import Foundation

public enum Log {
    case unmatchedUserDefaultsValue(value: String)
    case dictionaryValueNotFound(dictionary: [String: TimeInterval])
}

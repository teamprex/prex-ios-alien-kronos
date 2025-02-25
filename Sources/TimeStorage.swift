import Foundation

/// Defines where the user defaults are stored
public enum TimeStoragePolicy {
    /// Uses `UserDefaults.Standard`
    case standard
    /// Attempts to use the specified App Group ID (which is the String) to access shared storage.
    case appGroup(String)

    /// Creates an instance
    ///
    /// - parameter appGroupID: The App Group ID that maps to a shared container for `UserDefaults`. If this
    ///                         is nil, the resulting instance will be `.standard`
    public init(appGroupID: String?) {
        if let appGroupID = appGroupID {
            self = .appGroup(appGroupID)
        } else {
            self = .standard
        }
    }
}

/// Handles saving and retrieving instances of `TimeFreeze` for quick retrieval
public struct TimeStorage {
    private var userDefaults: UserDefaults
    private let kDefaultsKey = "PrexKronosStableTimeStorageKey"

    private let lock = NSLock()

    /// Thread-safe logging function
    var log: ((Log) -> Void)? {
        get {
            lock.lock()
            defer { lock.unlock() }
            return _log
        }
        set {
            lock.lock()
            _log = newValue
            lock.unlock()
        }
    }
    private var _log: ((Log) -> Void)?

    /// The most recent stored `TimeFreeze`. Getting retrieves from the UserDefaults defined by the storage
    /// policy. Setting sets the value in UserDefaults
    var stableTime: TimeFreeze? {
        get {
            guard let stored = self.userDefaults.value(forKey: kDefaultsKey) as? [String: TimeInterval] else {
                if userDefaults.value(forKey: kDefaultsKey) != nil {
                    log?(.unmatchedUserDefaultsValue(value: userDefaults.value(forKey: kDefaultsKey).debugDescription))
                }
                return nil
            }
            guard let previousStableTime = TimeFreeze(from: stored, log: log) else {
                return nil
            }

            return previousStableTime
        }

        set {
            guard let newFreeze = newValue else {
                return
            }

            self.userDefaults.set(newFreeze.toDictionary(), forKey: kDefaultsKey)
        }
    }

    /// Creates an instance
    ///
    /// - parameter storagePolicy: Defines the storage location of `UserDefaults`
    public init(storagePolicy: TimeStoragePolicy) {
        switch storagePolicy {
        case .standard:
            self.userDefaults = .standard
        case .appGroup(let groupName):
            let sharedDefaults = UserDefaults(suiteName: groupName)
            assert(sharedDefaults != nil, "Could not create UserDefaults for group: '\(groupName)'")
            self.userDefaults = sharedDefaults ?? .standard
        }
    }
}

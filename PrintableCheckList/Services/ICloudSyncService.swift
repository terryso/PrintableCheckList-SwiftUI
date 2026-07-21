import Foundation

@MainActor
protocol ICloudSyncServicing: AnyObject {
    func start(onExternalChange: @escaping @MainActor (Data) -> Void)
    func stop()
    func load() -> Data?
    func save(_ data: Data)
}

@MainActor
final class ICloudSyncService: ICloudSyncServicing {
    private let store: NSUbiquitousKeyValueStore
    private let notificationCenter: NotificationCenter
    private var observer: NSObjectProtocol?

    init(
        store: NSUbiquitousKeyValueStore = .default,
        notificationCenter: NotificationCenter = .default
    ) {
        self.store = store
        self.notificationCenter = notificationCenter
    }

    func start(onExternalChange: @escaping @MainActor (Data) -> Void) {
        guard observer == nil else { return }

        observer = notificationCenter.addObserver(
            forName: NSUbiquitousKeyValueStore.didChangeExternallyNotification,
            object: store,
            queue: .main
        ) { [weak self] notification in
            guard
                let self,
                Self.shouldApply(notification),
                let data = self.store.data(forKey: Self.projectsKey)
            else {
                return
            }
            Task { @MainActor in
                onExternalChange(data)
            }
        }
        store.synchronize()
    }

    func stop() {
        if let observer {
            notificationCenter.removeObserver(observer)
            self.observer = nil
        }
    }

    func load() -> Data? {
        store.data(forKey: Self.projectsKey)
    }

    func save(_ data: Data) {
        store.set(data, forKey: Self.projectsKey)
        store.synchronize()
    }

    private static let projectsKey = "keyProjects"

    private static func shouldApply(_ notification: Notification) -> Bool {
        guard
            let reasonValue = notification.userInfo?[NSUbiquitousKeyValueStoreChangeReasonKey]
                as? NSNumber
        else {
            return false
        }
        let reason = reasonValue.intValue
        guard
            reason == NSUbiquitousKeyValueStoreServerChange
                || reason == NSUbiquitousKeyValueStoreInitialSyncChange
        else {
            return false
        }

        let changedKeys = notification.userInfo?[NSUbiquitousKeyValueStoreChangedKeysKey]
            as? [String]
        return changedKeys?.contains(projectsKey) ?? true
    }

    deinit {
        if let observer {
            notificationCenter.removeObserver(observer)
        }
    }
}

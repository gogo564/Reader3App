import Foundation
import Network

extension Notification.Name {
    static let networkStatusChanged = Notification.Name("networkStatusChanged")
}

class NetworkMonitor {
    static let shared = NetworkMonitor()
    private let monitor = NWPathMonitor()
    private let queue = DispatchQueue(label: "network.monitor")

    private(set) var isConnected = true
    private(set) var isCellular = false

    private init() {
        monitor.pathUpdateHandler = { [weak self] path in
            let connected = path.status == .satisfied
            let cellular = path.isExpensive
            if self?.isConnected != connected || self?.isCellular != cellular {
                self?.isConnected = connected
                self?.isCellular = cellular
                DispatchQueue.main.async {
                    NotificationCenter.default.post(name: .networkStatusChanged, object: nil)
                }
            }
        }
        monitor.start(queue: queue)
    }

    deinit {
        monitor.cancel()
    }
}

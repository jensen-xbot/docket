import Foundation
import Network
import _Concurrency

@MainActor
@Observable
class NetworkMonitor {
    private let monitor = NWPathMonitor()
    private let queue = DispatchQueue(label: "NetworkMonitor")
    
    var isConnected = true // Default to true; NWPathMonitor fires immediately with actual state
    var onReconnect: (() -> Void)?
    
    init() {
        startMonitoring()
    }
    
    private func startMonitoring() {
        // pathUpdateHandler fires on the background `queue` — must hop to @MainActor
        // before touching any @Observable properties to avoid dispatch_assert_queue crash.
        monitor.pathUpdateHandler = { [weak self] path in
            let isSatisfied = path.status == .satisfied
            _Concurrency.Task { @MainActor [weak self] in
                guard let self else { return }
                let wasConnected = self.isConnected
                self.isConnected = isSatisfied
                
                // Trigger reconnect callback when transitioning from disconnected to connected
                if !wasConnected && self.isConnected {
                    self.onReconnect?()
                }
            }
        }
        monitor.start(queue: queue)
        // NWPathMonitor fires pathUpdateHandler immediately after start(),
        // so no separate initial-state check is needed.
    }
    
    deinit {
        monitor.cancel()
    }
}

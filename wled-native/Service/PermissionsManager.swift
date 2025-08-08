import Foundation
import Network
import Combine
import AppKit

@MainActor
class PermissionsManager: ObservableObject {
    static let shared = PermissionsManager()
    
    @Published var networkPermissionStatus: PermissionStatus = .unknown
    @Published var localNetworkPermissionStatus: PermissionStatus = .unknown
    @Published var showPermissionsSetup: Bool = false

    private var networkMonitor: NWPathMonitor?
    private var bonjourBrowser: NWBrowser?
    private var cancellables = Set<AnyCancellable>()

    enum PermissionStatus {
        case unknown, granted, denied
    }
    
    var hasLocalNetworkAccess: Bool {
        return localNetworkPermissionStatus == .granted
    }

    private init() {
        // Delay the check slightly to ensure the app window is ready
        Task {
            try await Task.sleep(nanoseconds: 500_000_000) // 0.5 seconds
            await self.checkPermissions()
        }
    }

    deinit {
        networkMonitor?.cancel()
        bonjourBrowser?.cancel()
    }

    func checkPermissions() async {
        checkBasicNetworkAccess()
        checkLocalNetworkAccess()

        // Combine the status of both permissions to determine if the setup view should be shown
        Publishers.CombineLatest($networkPermissionStatus, $localNetworkPermissionStatus)
            .map { netStatus, localNetStatus in
                // Show setup if we don't know the status yet, or if anything is denied.
                return netStatus != .granted || localNetStatus != .granted
            }
            .assign(to: \.showPermissionsSetup, on: self)
            .store(in: &cancellables)
    }

    private func checkBasicNetworkAccess() {
        networkMonitor = NWPathMonitor()
        networkMonitor?.pathUpdateHandler = { [weak self] path in
            DispatchQueue.main.async {
                if path.status == .satisfied {
                    self?.networkPermissionStatus = .granted
                } else {
                    self?.networkPermissionStatus = .denied
                }
                // We can cancel the monitor after the first update, as we only need to know if the interface is available.
                self?.networkMonitor?.cancel()
            }
        }
        networkMonitor?.start(queue: DispatchQueue.global(qos: .background))
    }

    private func checkLocalNetworkAccess() {
        // Using a Bonjour browser is a common way to trigger the local network permission dialog.
        let parameters = NWParameters()
        parameters.includePeerToPeer = true
        
        bonjourBrowser = NWBrowser(for: .bonjour(type: "_http._tcp", domain: "local"), using: parameters)
        
        bonjourBrowser?.browseResultsChangedHandler = { results, changes in
            // We don't need to do anything with the results,
            // but having the handler can sometimes help ensure the browser is active.
            print("Bonjour results changed: \(results.count) results")
        }
        
        bonjourBrowser?.stateUpdateHandler = { [weak self] newState in
            DispatchQueue.main.async {
                switch newState {
                case .ready:
                    self?.localNetworkPermissionStatus = .granted
                    self?.bonjourBrowser?.cancel() // We can stop once we get a ready state.
                case .failed(let error):
                    // A failure here often indicates that the user has denied permission.
                    print("Local network permission denied or failed: \(error.localizedDescription)")
                    self?.localNetworkPermissionStatus = .denied
                    self?.bonjourBrowser?.cancel()
                case .setup, .waiting:
                    // The status is still being determined.
                    self?.localNetworkPermissionStatus = .unknown
                default:
                    break
                }
            }
        }
        bonjourBrowser?.start(queue: .global(qos: .background))
    }
    
    func requestPermissions() {
        // This will re-trigger the check, and if permissions are unknown, it should prompt the user.
        checkLocalNetworkAccess()
    }
    
    func openSystemPreferences() {
        if let url = URL(string: "x-apple.systempreferences:com.apple.preference.security?Privacy_LocalNetwork") {
             NSWorkspace.shared.open(url)
        }
    }
    
    var allPermissionsGranted: Bool {
        networkPermissionStatus == .granted && localNetworkPermissionStatus == .granted
    }
}

import SwiftUI
import Combine

class AppState: ObservableObject {
    static let shared = AppState()
    
    @Published var showAddDevice = false
    @Published var triggerRefresh = false
    @Published var triggerDiscovery = false
    
    private init() {}
    
    func showAddDeviceSheet() {
        showAddDevice = true
    }
    
    func refreshAllDevices() {
        triggerRefresh = true
    }
    
    func startDiscovery() {
        triggerDiscovery = true
    }
}

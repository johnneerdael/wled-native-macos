import Foundation

extension Device {
    var requestManager: WLEDRequestManager {
        get {
            return DeviceStateFactory.shared.getStateForDevice(self).getRequestManager(device: self)
        }
    }
    
    func getColor(state: WledState) -> Int64 {
        let colorInfo = state.segment?[0].colors?[0]
        let red = Int64(Double(colorInfo![0]) + 0.5)
        let green = Int64(Double(colorInfo![1]) + 0.5)
        let blue = Int64(Double(colorInfo![2]) + 0.5)
        return (red << 16) | (green << 8) | blue
    }
    
    func setStateValues(state: WledState) {
        // Only update state if device is actually online and values have changed
        let wasOnline = isOnline
        let wasPoweredOn = isPoweredOn
        let oldBrightness = brightness
        let oldColor = color
        
        isOnline = true
        brightness = state.brightness
        isPoweredOn = state.isOn
        isRefreshing = false
        color = getColor(state: state)
        
        // Log state changes for debugging
        if !wasOnline {
            print("Device \(address ?? "unknown") came online")
        }
        if wasPoweredOn != isPoweredOn {
            print("Device \(address ?? "unknown") power state changed: \(wasPoweredOn) -> \(isPoweredOn)")
        }
        if oldBrightness != brightness {
            print("Device \(address ?? "unknown") brightness changed: \(oldBrightness) -> \(brightness)")
        }
    }
    
    // MARK: - macOS Enhancement: Device verification for discovery
    // Static method for device verification during discovery
    static func verifyDevice(at address: String) async -> Info? {
        // Create a temporary device for verification purposes
        let viewContext = PersistenceController.shared.container.viewContext
        var tempDevice: Device!
        
        await viewContext.perform {
            tempDevice = Device(context: viewContext)
            tempDevice.address = address
        }
        
        let requestManager = WLEDRequestManager(device: tempDevice)
        let request = WLEDRefreshRequest(context: viewContext)
        
        await requestManager.addRequest(request)
        
        // Wait for the request to complete and return the info
        return await request.getInfo()
    }
}

extension Device: Observable { }

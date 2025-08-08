import Foundation
import Network
import CoreData

struct WLEDDiscoveryResult: Identifiable {
    let id = UUID()
    let ip: String
    let name: String
    let version: String?
    let brand: String?
}

class SubnetDiscoveryService: ObservableObject {
    @Published var isScanning = false
    @Published var scanProgress: Double = 0.0
    @Published var checkedIPs = 0
    @Published var totalIPs = 0
    @Published var foundDevices: [WLEDDiscoveryResult] = []
    @Published var subnetInput = ""
    @Published var inputError = ""
    
    private var scanTask: Task<Void, Never>?
    
    struct SubnetScanResult: Identifiable {
        let id = UUID()
        let ipAddress: String
        let isWLEDDevice: Bool
        let deviceName: String?
        let version: String?
        let brand: String?
        let responseTime: TimeInterval
        let error: String?
    }
    
    // MARK: - Public Methods
    
    func startScanning() async {
        guard !isScanning else { return }
        
        // Validate input
        await MainActor.run {
            inputError = ""
        }
        
        let subnet = subnetInput.trimmingCharacters(in: .whitespaces)
        guard !subnet.isEmpty else {
            await MainActor.run {
                inputError = "Please enter a subnet to scan"
            }
            return
        }
        
        let ipAddresses = generateIPAddresses(for: subnet)
        guard !ipAddresses.isEmpty else {
            await MainActor.run {
                inputError = "Invalid subnet format"
            }
            return
        }
        
        // Limit scan size for practical purposes
        if ipAddresses.count > 1024 {
            await MainActor.run {
                inputError = "Subnet too large (max 1024 addresses). Use a smaller range."
            }
            return
        }
        
        stopScanning()
        
        scanTask = Task {
            await performSubnetScan(ipAddresses)
        }
    }
    
    func stopScanning() {
        scanTask?.cancel()
        scanTask = nil
        
        Task { @MainActor in
            isScanning = false
            scanProgress = 0.0
        }
    }
    
    func addSelectedDevices(selectedIPs: Set<String>) async {
        let devicesToAdd = foundDevices.filter { selectedIPs.contains($0.ip) }
        
        for device in devicesToAdd {
            await addDeviceToCore(device)
        }
    }
    
    // MARK: - Private Methods
    
    private func performSubnetScan(_ ipAddresses: [String]) async {
        await MainActor.run {
            isScanning = true
            scanProgress = 0.0
            checkedIPs = 0
            totalIPs = ipAddresses.count
            foundDevices.removeAll()
        }
        
        print("SubnetDiscoveryService: Starting scan of \(ipAddresses.count) addresses")
        
        // Scan in batches to avoid overwhelming the network
        let batchSize = 20
        var completedCount = 0
        
        for i in stride(from: 0, to: ipAddresses.count, by: batchSize) {
            if Task.isCancelled { break }
            
            let endIndex = min(i + batchSize, ipAddresses.count)
            let batch = Array(ipAddresses[i..<endIndex])
            
            await withTaskGroup(of: SubnetScanResult?.self) { group in
                for ipAddress in batch {
                    if Task.isCancelled { return }
                    
                    group.addTask {
                        await self.scanSingleIP(ipAddress)
                    }
                }
                
                for await result in group {
                    if Task.isCancelled { break }
                    
                    if let result = result, result.isWLEDDevice {
                        let discoveryResult = WLEDDiscoveryResult(
                            ip: result.ipAddress,
                            name: result.deviceName ?? "Unknown WLED Device",
                            version: result.version,
                            brand: result.brand
                        )
                        
                        await MainActor.run {
                            self.foundDevices.append(discoveryResult)
                        }
                    }
                    
                    completedCount += 1
                    await MainActor.run {
                        self.checkedIPs = completedCount
                        self.scanProgress = Double(completedCount) / Double(ipAddresses.count)
                    }
                }
            }
            
            // Small delay between batches to prevent network flooding
            try? await Task.sleep(nanoseconds: 100_000_000) // 0.1 seconds
        }
        
        await MainActor.run {
            isScanning = false
            scanProgress = 1.0
        }
        
        print("SubnetDiscoveryService: Scan completed. Found \(foundDevices.count) WLED devices")
    }
    
    private func scanSingleIP(_ ipAddress: String) async -> SubnetScanResult? {
        let startTime = Date()
        
        // First, check if port 80 is open
        let portCheckResult = await checkPort80(ipAddress: ipAddress)
        
        guard portCheckResult.isOpen else {
            return SubnetScanResult(
                ipAddress: ipAddress,
                isWLEDDevice: false,
                deviceName: nil,
                version: nil,
                brand: nil,
                responseTime: Date().timeIntervalSince(startTime),
                error: portCheckResult.error
            )
        }
        
        // Port 80 is open, now check if it's a WLED device
        let wledCheckResult = await checkIfWLEDDevice(ipAddress: ipAddress)
        
        return SubnetScanResult(
            ipAddress: ipAddress,
            isWLEDDevice: wledCheckResult.isWLED,
            deviceName: wledCheckResult.deviceName,
            version: wledCheckResult.version,
            brand: wledCheckResult.brand,
            responseTime: Date().timeIntervalSince(startTime),
            error: wledCheckResult.error
        )
    }
    
    private func checkPort80(ipAddress: String) async -> (isOpen: Bool, error: String?) {
        return await withCheckedContinuation { continuation in
            let connection = NWConnection(host: NWEndpoint.Host(ipAddress), port: 80, using: .tcp)
            
            var hasResumed = false
            
            connection.stateUpdateHandler = { state in
                switch state {
                case .ready:
                    if !hasResumed {
                        hasResumed = true
                        connection.cancel()
                        continuation.resume(returning: (true, nil))
                    }
                case .failed(let error):
                    if !hasResumed {
                        hasResumed = true
                        connection.cancel()
                        continuation.resume(returning: (false, error.localizedDescription))
                    }
                default:
                    break
                }
            }
            
            connection.start(queue: .global())
            
            // Timeout after 2 seconds
            DispatchQueue.global().asyncAfter(deadline: .now() + 2.0) {
                if !hasResumed {
                    hasResumed = true
                    connection.cancel()
                    continuation.resume(returning: (false, "Timeout"))
                }
            }
        }
    }
    
    private func checkIfWLEDDevice(ipAddress: String) async -> (isWLED: Bool, deviceName: String?, version: String?, brand: String?, error: String?) {
        guard let url = URL(string: "http://\(ipAddress)/json/si") else {
            return (false, nil, nil, nil, "Invalid URL")
        }
        
        do {
            let sessionConfig = URLSessionConfiguration.default
            sessionConfig.timeoutIntervalForRequest = 3
            sessionConfig.timeoutIntervalForResource = 5
            let session = URLSession(configuration: sessionConfig)
            
            let (data, response) = try await session.data(from: url)
            
            guard let httpResponse = response as? HTTPURLResponse,
                  (200...299).contains(httpResponse.statusCode) else {
                return (false, nil, nil, nil, "HTTP error")
            }
            
            // Try to parse as WLED JSON response
            do {
                let deviceStateInfo = try JSONDecoder().decode(DeviceStateInfo.self, from: data)
                let deviceName = deviceStateInfo.info.name ?? "Unknown WLED Device"
                let version = deviceStateInfo.info.version
                let brand = deviceStateInfo.info.brand
                return (true, deviceName, version, brand, nil)
            } catch {
                // Not a valid WLED response
                return (false, nil, nil, nil, "Not a WLED device")
            }
        } catch {
            return (false, nil, nil, nil, error.localizedDescription)
        }
    }
    
    private func generateIPAddresses(for subnet: String) -> [String] {
        // Support different subnet formats:
        // 192.168.1.0/24
        // 192.168.1.1-192.168.1.254
        // 192.168.1.*
        
        if subnet.contains("/") {
            return generateIPsFromCIDR(subnet)
        } else if subnet.contains("-") {
            return generateIPsFromRange(subnet)
        } else if subnet.contains("*") {
            return generateIPsFromWildcard(subnet)
        } else {
            // Single IP
            return [subnet]
        }
    }
    
    private func generateIPsFromCIDR(_ cidr: String) -> [String] {
        let components = cidr.components(separatedBy: "/")
        guard components.count == 2,
              let prefixLength = Int(components[1]),
              prefixLength >= 0 && prefixLength <= 30 else { // Max /30 for practical scanning
            return []
        }
        
        let baseIP = components[0]
        let ipComponents = baseIP.components(separatedBy: ".").compactMap { Int($0) }
        guard ipComponents.count == 4,
              ipComponents.allSatisfy({ $0 >= 0 && $0 <= 255 }) else {
            return []
        }
        
        let hostBits = 32 - prefixLength
        let maxHosts = min(1 << hostBits, 254) // Limit to 254 hosts for practical scanning
        
        var ips: [String] = []
        
        // Calculate network address
        let baseAddress = (ipComponents[0] << 24) | (ipComponents[1] << 16) | (ipComponents[2] << 8) | ipComponents[3]
        let networkMask = ~((1 << hostBits) - 1)
        let networkAddress = baseAddress & networkMask
        
        // Generate host addresses (skip network and broadcast)
        for i in 1..<(maxHosts - 1) {
            let hostAddress = networkAddress | i
            let ip = "\((hostAddress >> 24) & 0xFF).\((hostAddress >> 16) & 0xFF).\((hostAddress >> 8) & 0xFF).\(hostAddress & 0xFF)"
            ips.append(ip)
        }
        
        return ips
    }
    
    private func generateIPsFromRange(_ range: String) -> [String] {
        let components = range.components(separatedBy: "-")
        guard components.count == 2 else { return [] }
        
        let startIP = components[0].trimmingCharacters(in: .whitespaces)
        let endIP = components[1].trimmingCharacters(in: .whitespaces)
        
        let startComponents = startIP.components(separatedBy: ".").compactMap { Int($0) }
        let endComponents = endIP.components(separatedBy: ".").compactMap { Int($0) }
        
        guard startComponents.count == 4, endComponents.count == 4 else { return [] }
        
        // For simplicity, only support ranges in the last octet
        guard startComponents[0] == endComponents[0],
              startComponents[1] == endComponents[1],
              startComponents[2] == endComponents[2],
              startComponents[3] <= endComponents[3] else { return [] }
        
        var ips: [String] = []
        for i in startComponents[3]...endComponents[3] {
            let ip = "\(startComponents[0]).\(startComponents[1]).\(startComponents[2]).\(i)"
            ips.append(ip)
        }
        
        return ips
    }
    
    private func generateIPsFromWildcard(_ wildcard: String) -> [String] {
        let components = wildcard.components(separatedBy: ".")
        guard components.count == 4, components.last == "*" else { return [] }
        
        let baseComponents = Array(components.dropLast()).compactMap { Int($0) }
        guard baseComponents.count == 3 else { return [] }
        
        var ips: [String] = []
        for i in 1...254 {
            let ip = "\(baseComponents[0]).\(baseComponents[1]).\(baseComponents[2]).\(i)"
            ips.append(ip)
        }
        
        return ips
    }
    
    // MARK: - Device Management
    
    private func addDeviceToCore(_ device: WLEDDiscoveryResult) async {
        let viewContext = PersistenceController.shared.container.viewContext
        
        await withCheckedContinuation { continuation in
            viewContext.perform {
                // Check if device already exists
                let fetchRequest: NSFetchRequest<Device> = Device.fetchRequest()
                fetchRequest.predicate = NSPredicate(format: "address LIKE %@", device.ip)
                
                do {
                    let existingDevices = try viewContext.fetch(fetchRequest)
                    
                    if existingDevices.isEmpty {
                        // Device doesn't exist, create new one
                        print("SubnetDiscoveryService: Adding new device \(device.name) at \(device.ip)")
                        let newDevice = Device(context: viewContext)
                        newDevice.tag = UUID()
                        newDevice.name = device.name
                        newDevice.address = device.ip
                        newDevice.isHidden = false
                        newDevice.isOnline = true
                        newDevice.isCustomName = false
                        
                        try viewContext.save()
                        
                        // Trigger initial refresh
                        Task {
                            await newDevice.requestManager.addRequest(WLEDRefreshRequest(context: viewContext))
                        }
                    } else {
                        print("SubnetDiscoveryService: Device at \(device.ip) already exists")
                    }
                } catch {
                    print("Error adding device from subnet scan: \(error)")
                }
                
                continuation.resume()
            }
        }
    }
}

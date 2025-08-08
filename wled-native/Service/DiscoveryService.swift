import Foundation
import Combine
import CoreData
import Network
import SwiftUI

class DiscoveryService: NSObject, Identifiable {
    
    var browser: NWBrowser!
    
    func scan() {
        // MARK: - macOS Enhancement: Trigger Local Network permission prompt
        // We need to do an actual network operation to trigger the permission dialog
        let testConnection = NWConnection(host: "192.168.1.1", port: 80, using: .tcp)
        testConnection.stateUpdateHandler = { _ in }
        testConnection.start(queue: .global())
        // Don't wait for this connection, just trigger the permission
        DispatchQueue.global().asyncAfter(deadline: .now() + 0.1) {
            testConnection.cancel()
        }
        
        // MARK: - macOS Enhancement: Use _http._tcp for better discovery
        let bonjourTCP = NWBrowser.Descriptor.bonjour(type: "_http._tcp" , domain: "local.")
        
        let bonjourParms = NWParameters.init()
        bonjourParms.allowLocalEndpointReuse = true
        bonjourParms.acceptLocalOnly = true
        bonjourParms.allowFastOpen = true
        
        browser = NWBrowser(for: bonjourTCP, using: bonjourParms)
        browser.stateUpdateHandler = {newState in
            switch newState {
            case .failed(let error):
                print("NW Browser: now in Error state: \(error)")
                self.browser.cancel()
            case .ready:
                print("NW Browser: new bonjour discovery - ready")
            case .setup:
                print("NW Browser: in SETUP state")
            default:
                break
            }
        }
        browser.browseResultsChangedHandler = { ( results, changes ) in
            print("NW Browser: Scan results found:")
            for result in results {
                print(result.endpoint.debugDescription)
            }
            for change in changes {
                if case .added(let added) = change {
                    print("NW Browser: Added")
                    if case .service(let name, _, _, _) = added.endpoint {
                        print("Connecting to \(name)")
                        let connection = NWConnection(to: added.endpoint, using: .tcp)
                        connection.stateUpdateHandler = { state in
                            switch state {
                            case .ready:
                                if let innerEndpoint = connection.currentPath?.remoteEndpoint,
                                   case .hostPort(let host, let port) = innerEndpoint {
                                    let remoteHost = "\(host)".split(separator: "%")[0]
                                    print("Connected to", "\(remoteHost):\(port)")
                                    // MARK: - macOS Enhancement: Verify device before adding
                                    self.verifyAndAddDevice(name: name, host: "\(remoteHost)")
                                }
                            default:
                                break
                            }
                        }
                        connection.start(queue: .global())
                    }
                }
            }
        }
        self.browser.start(queue: DispatchQueue.main)
    }
    
    // MARK: - macOS Enhancement: Device verification
    private func verifyAndAddDevice(name: String, host: String) {
        Task {
            // Use the Device.verifyDevice static method to check if it's a WLED device
            let info = await Device.verifyDevice(at: host)
            
            // If we get back valid info, it's a WLED device.
            if info != nil {
                print("DiscoveryService: Verified \(name) at \(host) is a WLED device.")
                addDevice(name: name, host: host)
            } else {
                print("DiscoveryService: \(name) at \(host) is not a WLED device.")
            }
        }
    }
    
    func addDevice(name: String, host: String) {
        let viewContext = PersistenceController.shared.container.viewContext
        viewContext.performAndWait {
            // Check if device already exists
            let fetchRequest: NSFetchRequest<Device> = Device.fetchRequest()
            fetchRequest.predicate = NSPredicate(format: "address LIKE %@", host)
            
            do {
                let existingDevices = try viewContext.fetch(fetchRequest)
                
                if let existingDevice = existingDevices.first {
                    // Device already exists - only update if it was previously offline or if we need to update the name
                    print("DiscoveryService: Device \(host) already exists")
                    
                    // Update the name if it wasn't custom-named
                    if existingDevice.name?.isEmpty ?? true || !(existingDevice.isCustomName) {
                        existingDevice.name = name
                        existingDevice.isCustomName = false
                    }
                    
                    // Only mark as online and refresh if it was previously offline or refreshing isn't in progress
                    if !existingDevice.isOnline {
                        print("DiscoveryService: Marking previously offline device \(host) as online")
                        existingDevice.isOnline = true
                        
                        // Only trigger a refresh if not already refreshing
                        if !existingDevice.isRefreshing {
                            Task {
                                await existingDevice.requestManager.addRequest(WLEDRefreshRequest(context: viewContext))
                            }
                        }
                    }
                    
                    try viewContext.save()
                    return
                }
            } catch {
                print("Error checking for existing device: \(error)")
            }
            
            // Device doesn't exist, create new one
            print("DiscoveryService: Creating new device \(name) at \(host)")
            let newDevice = Device(context: viewContext)
            newDevice.tag = UUID()
            newDevice.name = name
            newDevice.address = host
            newDevice.isHidden = false
            newDevice.isOnline = true  // Mark as online since we just discovered it
            
            do {
                try viewContext.save()
                
                // Trigger initial refresh
                Task {
                    await newDevice.requestManager.addRequest(WLEDRefreshRequest(context: viewContext))
                }
            } catch {
                print("Error saving new device: \(error)")
            }
        }
    }
}

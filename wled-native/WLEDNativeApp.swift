import SwiftUI

@main
struct WLEDNativeApp: App {
    static let dateLastUpdateKey = "lastUpdateReleasesDate"
    
    let persistenceController = PersistenceController.shared
    @StateObject private var appState = AppState.shared
    @StateObject private var permissionsManager = PermissionsManager.shared
    
    var body: some Scene {
        WindowGroup {
            Group {
                if permissionsManager.showPermissionsSetup {
                    PermissionsSetupView(permissionsManager: permissionsManager)
                } else {
                    DeviceListViewFabric.make()
                        .environment(\.managedObjectContext, persistenceController.container.viewContext)
                        .environmentObject(appState)
                        .onAppear() {
                            refreshVersionsSync()
                        }
                }
            }
        }
        .windowStyle(.hiddenTitleBar)
        .windowToolbarStyle(.unified(showsTitle: false))
        .defaultSize(width: 1200, height: 800)
        .windowResizability(.contentSize)
        .commands {
            CommandGroup(replacing: .newItem) {
                Button("Add Device...") {
                    appState.showAddDeviceSheet()
                }
                .keyboardShortcut("n", modifiers: .command)
            }
            
            CommandGroup(after: .windowArrangement) {
                Button("Refresh All Devices") {
                    appState.refreshAllDevices()
                }
                .keyboardShortcut("r", modifiers: .command)
                
                Button("Discover WLED Devices") {
                    appState.startDiscovery()
                }
                .keyboardShortcut("d", modifiers: [.command, .shift])
            }
        }
        
        Settings {
            SettingsView()
                .environmentObject(appState)
        }
    }
    
    private func refreshVersionsSync() {
        Task {
            // Only update automatically from Github once per 24 hours to avoid rate limits
            // and reduce network usage.
            let date = Date(timeIntervalSince1970: UserDefaults.standard.double(forKey: WLEDNativeApp.dateLastUpdateKey))
            var dateComponent = DateComponents()
            dateComponent.day = 1
            let dateToRefresh = Calendar.current.date(byAdding: dateComponent, to: date)
            let dateNow = Date()
            guard let dateToRefresh = dateToRefresh else {
                return
            }
            if (dateNow <= dateToRefresh) {
                return
            }
            print("Refreshing available Releases")
            await ReleaseService(context: persistenceController.container.viewContext).refreshVersions()
            UserDefaults.standard.set(Date().timeIntervalSince1970, forKey: WLEDNativeApp.dateLastUpdateKey)
        }
    }
}
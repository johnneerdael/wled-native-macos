import SwiftUI

struct SettingsView: View {
    var body: some View {
        TabView {
            GeneralSettingsView()
                .tabItem {
                    Label("General", systemImage: "gear")
                }
            
            LanguageSettingsView()
                .tabItem {
                    Label("Language", systemImage: "globe")
                }
            
            NetworkSettingsView()
                .tabItem {
                    Label("Network", systemImage: "network")
                }
        }
        .frame(width: 500, height: 400)
        .sheetGlass()
    }
}

struct GeneralSettingsView: View {
    @AppStorage("showHiddenDevices") private var showHiddenDevices = false
    @AppStorage("showOfflineDevices") private var showOfflineDevices = true
    @AppStorage("autoRefreshInterval") private var autoRefreshInterval = 30.0
    
    var body: some View {
        Form {
            Section("Device Display") {
                Toggle("Show Hidden Devices", isOn: $showHiddenDevices)
                Toggle("Show Offline Devices", isOn: $showOfflineDevices)
            }
            
            Section("Auto-Refresh") {
                VStack(alignment: .leading) {
                    Text("Refresh Interval: \(Int(autoRefreshInterval)) seconds")
                    Slider(value: $autoRefreshInterval, in: 10...300, step: 10) {
                        Text("Refresh Interval")
                    }
                }
            }
        }
        .padding()
    }
}

struct LanguageSettingsView: View {
    @StateObject private var languageManager = LanguageManager.shared
    
    var body: some View {
        Form {
            Section("Application Language") {
                VStack(alignment: .leading, spacing: 12) {
                    Text("Choose your preferred language for the WLED Native interface:")
                        .foregroundColor(.secondary)
                    
                    Picker("Language", selection: $languageManager.currentLanguage) {
                        ForEach(Array(languageManager.supportedLanguages.keys.sorted()), id: \.self) { langCode in
                            Text(languageManager.getDisplayName(for: langCode))
                                .tag(langCode)
                        }
                    }
                    .pickerStyle(MenuPickerStyle())
                    
                    Text("Note: You may need to restart the app for language changes to take full effect.")
                        .font(.caption)
                        .foregroundColor(.orange)
                }
            }
            
            Section("Current Selection") {
                HStack {
                    Text("Selected Language:")
                    Spacer()
                    Text(languageManager.getDisplayName(for: languageManager.currentLanguage))
                        .foregroundColor(.secondary)
                }
            }
        }
        .padding()
    }
}

struct NetworkSettingsView: View {
    @StateObject private var appState = AppState.shared
    @StateObject private var permissionsManager = PermissionsManager.shared
    private let discoveryService = DiscoveryService()
    @State private var subnetDiscoveryActive = false
    
    var body: some View {
        Form {
            Section("Network Permissions") {
                VStack(alignment: .leading, spacing: 12) {
                    HStack {
                        Image(systemName: permissionsManager.hasLocalNetworkAccess ? "checkmark.circle.fill" : "xmark.circle.fill")
                            .foregroundColor(permissionsManager.hasLocalNetworkAccess ? .green : .red)
                        
                        VStack(alignment: .leading, spacing: 4) {
                            Text("Local Network Access")
                                .font(.headline)
                            Text(permissionsManager.hasLocalNetworkAccess ? "Granted" : "Required for device discovery")
                                .font(.caption)
                                .foregroundColor(.secondary)
                        }
                        
                        Spacer()
                    }
                    
                    if !permissionsManager.hasLocalNetworkAccess {
                        VStack(alignment: .leading, spacing: 8) {
                            Text("WLED Native needs Local Network permission to discover WLED devices on your network.")
                                .font(.caption)
                                .foregroundColor(.secondary)
                            
                            HStack {
                                Button("Check Permissions") {
                                    Task {
                                        await permissionsManager.checkPermissions()
                                    }
                                }
                                .buttonStyle(.bordered)
                                
                                Button("Open System Preferences") {
                                    permissionsManager.openSystemPreferences()
                                }
                                .buttonStyle(.borderedProminent)
                            }
                        }
                    }
                }
            }
            
            Section("Device Discovery") {
                VStack(alignment: .leading, spacing: 8) {
                    Text("WLED Native automatically discovers WLED devices on your local network using Bonjour/mDNS.")
                        .foregroundColor(.secondary)
                    
                    Text("Make sure your WLED devices and this Mac are on the same network.")
                        .foregroundColor(.secondary)
                }
                
                HStack {
                    Button("Discover Devices Now") {
                        Task {
                            // Check permissions first, then scan
                            await permissionsManager.checkPermissions()
                            if permissionsManager.hasLocalNetworkAccess {
                                discoveryService.scan()
                            }
                        }
                    }
                    .buttonStyle(.borderedProminent)
                    
                    Spacer()
                    
                    Text("⌘⇧D")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
                
                if !permissionsManager.hasLocalNetworkAccess {
                    Text("Local Network permission required for device discovery")
                        .font(.caption)
                        .foregroundColor(.orange)
                }
            }
            
            Section("Manual Configuration") {
                VStack(alignment: .leading, spacing: 8) {
                    Text("You can manually add devices by IP address or scan network subnets for WLED devices.")
                        .foregroundColor(.secondary)
                    
                    VStack(spacing: 8) {
                        HStack {
                            Button("Add Device Manually") {
                                appState.showAddDeviceSheet()
                            }
                            
                            Spacer()
                            
                            Text("⌘N")
                                .font(.caption)
                                .foregroundColor(.secondary)
                        }
                        
                        HStack {
                            Button("Subnet Discovery") {
                                subnetDiscoveryActive = true
                            }
                            .buttonStyle(.borderedProminent)
                            
                            Spacer()
                            
                            Text("⌘⇧S")
                                .font(.caption)
                                .foregroundColor(.secondary)
                        }
                    }
                }
            }
        }
        .padding()
        .sheet(isPresented: $subnetDiscoveryActive) {
            SubnetDiscoveryView()
        }
    }
}

#Preview {
    SettingsView()
}

import SwiftUI
import Network

struct SubnetDiscoveryView: View {
    @StateObject private var discoveryService = SubnetDiscoveryService()
    @Environment(\.dismiss) private var dismiss
    @State private var showingHelp = false
    @State private var selectedDevices = Set<String>()
    
    var body: some View {
        NavigationView {
            VStack(spacing: 20) {
                // Input Section
                VStack(alignment: .leading, spacing: 15) {
                    VStack(alignment: .leading, spacing: 8) {
                        HStack {
                            Text("Network to Scan")
                                .font(.headline)
                            
                            Spacer()
                            
                            Button(action: {
                                showingHelp = true
                            }) {
                                Image(systemName: "questionmark.circle")
                            }
                            .buttonStyle(.plain)
                            .help("Show help for subnet formats")
                        }
                        
                        TextField("Enter subnet (e.g., 192.168.1.0/24)", text: $discoveryService.subnetInput)
                            .textFieldStyle(.roundedBorder)
                            .disabled(discoveryService.isScanning)
                        
                        if !discoveryService.inputError.isEmpty {
                            Text(discoveryService.inputError)
                                .foregroundColor(.red)
                                .font(.caption)
                        }
                    }
                    
                    HStack {
                        Button(discoveryService.isScanning ? "Stop Scanning" : "Start Scan") {
                            if discoveryService.isScanning {
                                discoveryService.stopScanning()
                            } else {
                                Task {
                                    await discoveryService.startScanning()
                                }
                            }
                        }
                        .buttonStyle(.borderedProminent)
                        .disabled(discoveryService.subnetInput.isEmpty && !discoveryService.isScanning)
                        
                        if discoveryService.isScanning {
                            Button("Cancel") {
                                discoveryService.stopScanning()
                            }
                            .buttonStyle(.bordered)
                        }
                    }
                }
                .padding()
                .background(Color(NSColor.controlBackgroundColor))
                .cornerRadius(8)
                
                // Progress Section
                if discoveryService.isScanning || discoveryService.scanProgress > 0 {
                    VStack(alignment: .leading, spacing: 8) {
                        HStack {
                            Text("Scanning Progress")
                                .font(.headline)
                            Spacer()
                            if discoveryService.isScanning {
                                ProgressView()
                                    .scaleEffect(0.8)
                            }
                        }
                        
                        ProgressView(value: discoveryService.scanProgress, total: 1.0)
                        
                        HStack {
                            Text("Checked: \(discoveryService.checkedIPs)")
                            Spacer()
                            Text("Found: \(discoveryService.foundDevices.count)")
                            Spacer()
                            if discoveryService.totalIPs > 0 {
                                Text("Total: \(discoveryService.totalIPs)")
                            }
                        }
                        .font(.caption)
                        .foregroundColor(.secondary)
                    }
                    .padding()
                    .background(Color(NSColor.controlBackgroundColor))
                    .cornerRadius(8)
                }
                
                // Results Section
                if !discoveryService.foundDevices.isEmpty {
                    VStack(alignment: .leading, spacing: 10) {
                        HStack {
                            Text("Found WLED Devices (\(discoveryService.foundDevices.count))")
                                .font(.headline)
                            
                            Spacer()
                            
                            if selectedDevices.isEmpty {
                                Button("Select All") {
                                    selectedDevices = Set(discoveryService.foundDevices.map { $0.ip })
                                }
                                .buttonStyle(.bordered)
                            } else {
                                Button("Deselect All") {
                                    selectedDevices.removeAll()
                                }
                                .buttonStyle(.bordered)
                            }
                        }
                        
                        ScrollView {
                            LazyVStack(spacing: 8) {
                                ForEach(discoveryService.foundDevices, id: \.ip) { device in
                                    WLEDDeviceResultRow(
                                        device: device,
                                        isSelected: selectedDevices.contains(device.ip)
                                    ) { isSelected in
                                        if isSelected {
                                            selectedDevices.insert(device.ip)
                                        } else {
                                            selectedDevices.remove(device.ip)
                                        }
                                    }
                                }
                            }
                            .padding(.horizontal)
                        }
                        .background(Color(NSColor.controlBackgroundColor))
                        .cornerRadius(8)
                        .frame(maxHeight: 250)
                        
                        if !selectedDevices.isEmpty {
                            HStack {
                                Button("Add Selected Devices (\(selectedDevices.count))") {
                                    Task {
                                        await discoveryService.addSelectedDevices(selectedIPs: selectedDevices)
                                        dismiss()
                                    }
                                }
                                .buttonStyle(.borderedProminent)
                                
                                Spacer()
                                
                                Text("\(selectedDevices.count) of \(discoveryService.foundDevices.count) selected")
                                    .font(.caption)
                                    .foregroundColor(.secondary)
                            }
                        }
                    }
                    .padding()
                    .background(Color(NSColor.controlBackgroundColor))
                    .cornerRadius(8)
                }
                
                Spacer()
            }
            .padding()
            .navigationTitle("Subnet Discovery")
            .toolbar {
                ToolbarItem(placement: .primaryAction) {
                    Button("Close") {
                        dismiss()
                    }
                }
                
                ToolbarItem(placement: .secondaryAction) {
                    Button("Help") {
                        showingHelp = true
                    }
                }
            }
        }
        .frame(width: 600, height: 500)
        .sheetGlass()
        .sheet(isPresented: $showingHelp) {
            SubnetDiscoveryHelpView()
        }
    }
}

struct WLEDDeviceResultRow: View {
    let device: WLEDDiscoveryResult
    let isSelected: Bool
    let onToggle: (Bool) -> Void
    
    var body: some View {
        HStack(spacing: 12) {
            Button(action: {
                onToggle(!isSelected)
            }) {
                Image(systemName: isSelected ? "checkmark.circle.fill" : "circle")
                    .foregroundColor(isSelected ? .accentColor : .secondary)
            }
            .buttonStyle(.plain)
            
            VStack(alignment: .leading, spacing: 4) {
                HStack {
                    Text(device.name)
                        .font(.headline)
                        .lineLimit(1)
                    
                    Spacer()
                    
                    Text(device.ip)
                        .font(.caption)
                        .foregroundColor(.secondary)
                        .textSelection(.enabled)
                }
                
                if let version = device.version {
                    Text("Version: \(version)")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
                
                if let brand = device.brand {
                    Text("Brand: \(brand)")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
            }
            
            Spacer()
            
            VStack(alignment: .trailing, spacing: 4) {
                Image(systemName: "wifi")
                    .foregroundColor(.green)
                
                Text("Online")
                    .font(.caption)
                    .foregroundColor(.green)
            }
        }
        .padding()
        .background(isSelected ? Color.accentColor.opacity(0.1) : Color.clear)
        .cornerRadius(8)
        .overlay(
            RoundedRectangle(cornerRadius: 8)
                .stroke(isSelected ? Color.accentColor : Color.clear, lineWidth: 2)
        )
    }
}

struct SubnetDiscoveryHelpView: View {
    @Environment(\.dismiss) private var dismiss
    
    var body: some View {
        NavigationView {
            ScrollView {
                VStack(alignment: .leading, spacing: 20) {
                    VStack(alignment: .leading, spacing: 10) {
                        Text("Subnet Discovery Help")
                            .font(.largeTitle)
                            .fontWeight(.bold)
                        
                        Text("Find WLED devices on any network by scanning IP ranges.")
                            .font(.subheadline)
                            .foregroundColor(.secondary)
                    }
                    
                    VStack(alignment: .leading, spacing: 15) {
                        Text("Supported Formats")
                            .font(.headline)
                        
                        VStack(alignment: .leading, spacing: 12) {
                            HelpFormatView(
                                title: "CIDR Notation",
                                example: "192.168.1.0/24",
                                description: "Scans all IPs from 192.168.1.1 to 192.168.1.254"
                            )
                            HelpFormatView(
                                title: "IP Range",
                                example: "192.168.1.1-192.168.1.50",
                                description: "Scans IPs from 192.168.1.1 to 192.168.1.50"
                            )
                            HelpFormatView(
                                title: "Wildcard",
                                example: "192.168.1.*",
                                description: "Scans all IPs from 192.168.1.1 to 192.168.1.254"
                            )
                            HelpFormatView(
                                title: "Single IP",
                                example: "192.168.1.100",
                                description: "Checks only the specified IP address"
                            )
                        }
                        .background(Color(NSColor.controlBackgroundColor))
                        .cornerRadius(8)
                    }
                    
                    VStack(alignment: .leading, spacing: 15) {
                        Text("Common Network Ranges")
                            .font(.headline)
                        
                        VStack(alignment: .leading, spacing: 8) {
                            ForEach([
                                ("Home Networks", "192.168.1.0/24 or 192.168.0.0/24"),
                                ("Corporate Networks", "10.0.0.0/24 or 172.16.0.0/24"),
                                ("Small Subnets", "192.168.1.0/28 (16 addresses)")
                            ], id: \.0) { network in
                                HStack {
                                    Text(network.0)
                                        .fontWeight(.medium)
                                    Spacer()
                                    Text(network.1)
                                        .font(.caption)
                                        .font(.system(.caption, design: .monospaced))
                                        .foregroundColor(.secondary)
                                }
                                .padding(.vertical, 4)
                            }
                        }
                        .padding()
                        .background(Color(NSColor.controlBackgroundColor))
                        .cornerRadius(8)
                    }
                    
                    VStack(alignment: .leading, spacing: 10) {
                        Text("How It Works")
                            .font(.headline)
                        
                        VStack(alignment: .leading, spacing: 8) {
                            Label("Checks if each IP responds on port 80", systemImage: "network")
                            Label("Verifies it's a WLED device using the API", systemImage: "checkmark.shield")
                            Label("Shows device name, version, and brand info", systemImage: "info.circle")
                            Label("Lets you select and add multiple devices", systemImage: "plus.circle")
                        }
                        .font(.subheadline)
                    }
                    .padding()
                    .background(Color.blue.opacity(0.1))
                    .cornerRadius(8)
                    
                    VStack(alignment: .leading, spacing: 10) {
                        Text("Tips & Notes")
                            .font(.headline)
                        
                        VStack(alignment: .leading, spacing: 8) {
                            Label("Large ranges (like /16) can take a very long time", systemImage: "clock")
                                .foregroundColor(.orange)
                            Label("Use smaller ranges (/24 or /28) for faster results", systemImage: "speedometer")
                            Label("VPN networks may require additional permissions", systemImage: "lock.shield")
                            Label("Scanning only checks port 80 (HTTP)", systemImage: "globe")
                        }
                        .font(.subheadline)
                    }
                    .padding()
                    .background(Color.orange.opacity(0.1))
                    .cornerRadius(8)
                }
                .padding()
            }
            .navigationTitle("Help")
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Done") {
                        dismiss()
                    }
                }
            }
        }
        .frame(width: 500, height: 600)
        .sheetGlass()
    }
}
 
struct HelpFormatView: View {
    let title: String
    let example: String
    let description: String
    
    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            HStack {
                Text(title)
                    .font(.subheadline)
                    .fontWeight(.medium)
                Spacer()
                Text(example)
                    .font(.caption)
                    .font(.system(.caption, design: .monospaced))
                    .padding(.horizontal, 6)
                    .padding(.vertical, 2)
                    .background(Color(NSColor.controlBackgroundColor))
                    .cornerRadius(4)
            }
            Text(description)
                .font(.caption)
                .foregroundColor(.secondary)
        }
        .padding()
        .background(Color(NSColor.controlBackgroundColor).opacity(0.5))
        .cornerRadius(8)
    }
}

#Preview {
    SubnetDiscoveryView()
}

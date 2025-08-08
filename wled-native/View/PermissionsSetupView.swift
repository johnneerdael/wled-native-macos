import SwiftUI

struct PermissionsSetupView: View {
    @ObservedObject var permissionsManager: PermissionsManager

    var body: some View {
        VStack {
            if permissionsManager.showPermissionsSetup {
                ZStack {
                    LiquidGlassView()
                        .edgesIgnoringSafeArea(.all)

                    VStack(spacing: 20) {
                        Text("Permissions Required")
                            .font(.largeTitle)
                            .fontWeight(.bold)
                            .foregroundColor(.white)
                            .shadow(radius: 2)

                        Text("WLED Native requires Local Network access to discover and control your WLED devices. Please grant permission to continue.")
                            .font(.body)
                            .foregroundColor(.white.opacity(0.9))
                            .multilineTextAlignment(.center)
                            .padding(.horizontal)

                        VStack(alignment: .leading, spacing: 15) {
                            PermissionStatusRow(status: permissionsManager.networkPermissionStatus, text: "Internet Access")
                            PermissionStatusRow(status: permissionsManager.localNetworkPermissionStatus, text: "Local Network Access")
                        }
                        .padding()
                        .background(Color.black.opacity(0.2))
                        .cornerRadius(10)
                        .padding(.horizontal)

                        if permissionsManager.localNetworkPermissionStatus == .unknown {
                            Button(action: {
                                permissionsManager.requestPermissions()
                            }) {
                                Label("Grant Permission", systemImage: "lock.open.fill")
                                    .fontWeight(.semibold)
                                    .frame(minWidth: 0, maxWidth: .infinity)
                                    .padding()
                                    .foregroundColor(.white)
                                    .background(Color.green)
                                    .cornerRadius(10)
                                    .shadow(radius: 1)
                            }
                            .padding(.horizontal)
                        }

                        if permissionsManager.localNetworkPermissionStatus == .denied {
                            Button(action: {
                                permissionsManager.openSystemPreferences()
                            }) {
                                Label("Open System Settings", systemImage: "gear")
                                    .fontWeight(.semibold)
                                    .frame(minWidth: 0, maxWidth: .infinity)
                                    .padding()
                                    .foregroundColor(.white)
                                    .background(Color.blue)
                                    .cornerRadius(10)
                                    .shadow(radius: 1)
                            }
                            .padding(.horizontal)
                        }

                        Button(action: {
                            Task {
                                await permissionsManager.checkPermissions()
                            }
                        }) {
                            Label("Re-check Permissions", systemImage: "arrow.clockwise")
                                .fontWeight(.semibold)
                                .frame(minWidth: 0, maxWidth: .infinity)
                                .padding()
                                .foregroundColor(.white)
                                .background(permissionsManager.allPermissionsGranted ? Color.green : Color.gray)
                                .cornerRadius(10)
                                .shadow(radius: 1)
                        }
                        .padding(.horizontal)
                        .disabled(permissionsManager.localNetworkPermissionStatus == .unknown)
                        
                        if permissionsManager.localNetworkPermissionStatus == .unknown {
                            ProgressView("Checking permissions...")
                                .progressViewStyle(CircularProgressViewStyle(tint: .white))
                                .padding()
                        }
                    }
                    .padding()
                }
            } else {
                // This view will be replaced by the main app content once permissions are granted.
                // For now, we just show a success message.
                ZStack {
                     LiquidGlassView()
                        .edgesIgnoringSafeArea(.all)
                    Text("All permissions granted. Loading...")
                        .font(.largeTitle)
                        .foregroundColor(.white)
                }
            }
        }
        .onAppear {
            Task {
                await permissionsManager.checkPermissions()
            }
        }
        // Listen for changes and automatically dismiss when permissions are granted
        .onChange(of: permissionsManager.allPermissionsGranted) { allGranted in
            if allGranted {
                // In a real app, you would trigger a state change here to dismiss this view
                // and show the main content.
                print("All permissions have been granted!")
            }
        }
    }
}

struct PermissionStatusRow: View {
    let status: PermissionsManager.PermissionStatus
    let text: String

    var body: some View {
        HStack {
            Image(systemName: iconName)
                .foregroundColor(iconColor)
            Text(text)
                .foregroundColor(.white)
            Spacer()
        }
    }

    private var iconName: String {
        switch status {
        case .unknown:
            return "questionmark.circle"
        case .granted:
            return "checkmark.circle.fill"
        case .denied:
            return "xmark.circle.fill"
        }
    }

    private var iconColor: Color {
        switch status {
        case .unknown:
            return .yellow
        case .granted:
            return .green
        case .denied:
            return .red
        }
    }
}

struct PermissionsSetupView_Previews: PreviewProvider {
    static var previews: some View {
        PermissionsSetupView(permissionsManager: PermissionsManager.shared)
    }
}

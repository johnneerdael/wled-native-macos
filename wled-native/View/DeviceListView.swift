

import SwiftUI
import CoreData

//  This helper class creates the correct `DeviceListView` depending on the iOS version
struct DeviceListViewFabric {
    @ViewBuilder
    static func make() -> some View {
        DeviceListView()
    }
}

@available(macOS 13, *)
struct DeviceListView: View {
    
    private static let sort = [
        SortDescriptor(\Device.name, comparator: .localized, order: .forward)
    ]
    
    @Environment(\.managedObjectContext) private var viewContext
    @EnvironmentObject private var appState: AppState
    
    @FetchRequest(sortDescriptors: sort, animation: .default)
    private var devices: FetchedResults<Device>
    
    @FetchRequest(sortDescriptors: sort, animation: .default)
    private var devicesOffline: FetchedResults<Device>
    
    @State private var timer: Timer? = nil
    
    @State private var selection: Device? = nil
    
    @State private var addDeviceButtonActive: Bool = false
    @State private var subnetDiscoveryActive: Bool = false
    
    @SceneStorage("DeviceListView.showHiddenDevices") private var showHiddenDevices: Bool = false
    @SceneStorage("DeviceListView.showOfflineDevices") private var showOfflineDevices: Bool = true
    
    private let discoveryService = DiscoveryService()
    
    //MARK: - UI
    
    var body: some View {
        NavigationSplitView(columnVisibility: .constant(.all)) {
            list
                .navigationSplitViewColumnWidth(min: 280, ideal: 320, max: 400)
                .toolbar{ toolbar }
                .sheet(isPresented: $addDeviceButtonActive, content: DeviceAddView.init)
                .sheet(isPresented: $subnetDiscoveryActive) {
                    SubnetDiscoveryView()
                }
                .sidebarGlass()
        } detail: {
            detailView
                .navigationSplitViewColumnWidth(min: 500, ideal: 800)
                .contentGlass()
        }
            .onAppear(perform: appearAction)
            .onDisappear(perform: disappearAction)
            .onChange(of: showHiddenDevices) { _ in updateFilter() }
            .onChange(of: showOfflineDevices) { _ in updateFilter() }
            .onChange(of: appState.showAddDevice) { showSheet in
                if showSheet {
                    addDeviceButtonActive = true
                    appState.showAddDevice = false
                }
            }
            .onChange(of: appState.triggerRefresh) { refresh in
                if refresh {
                    Task {
                        await refreshList()
                    }
                    appState.triggerRefresh = false
                }
            }
            .onChange(of: appState.triggerDiscovery) { discover in
                if discover {
                    discoveryService.scan()
                    appState.triggerDiscovery = false
                }
            }
    }
    
    var list: some View {
        List(selection: $selection) {
            Section("Online Devices") {
                sublist(devices: devices)
            }
            if !devicesOffline.isEmpty && showOfflineDevices {
                Section("Offline Devices") {
                    sublist(devices: devicesOffline)
                }
            }
        }
        .listStyle(SidebarListStyle())
        .refreshable(action: refreshList)
        .frame(minWidth: 250)
    }
    
    private func sublist(devices: FetchedResults<Device>) -> some View {
        ForEach(devices) { device in
            NavigationLink(value: device) {
                DeviceListItemView()
            }
                .environmentObject(device)
                .contextMenu {
                    Button(role: .destructive) {
                        deleteItems(device: device)
                    } label: {
                        Label("Delete", systemImage: "trash.fill")
                    }
                }
        }
    }
    
    @ViewBuilder
    private var detailView: some View {
        if let device = selection {
            NavigationStack {
                DeviceView()
            }
                .environmentObject(device)
        } else {
            Text("Select A Device")
                .font(.title2)
        }
    }
    
    @ToolbarContentBuilder
    private var toolbar: some ToolbarContent {
        ToolbarItem(placement: .principal) {
            VStack {
                Image("wled_logo_akemi")
                    .resizable()
                    .scaledToFit()
                    .padding(2)
            }
            .frame(maxWidth: 200)
        }
        
        ToolbarItem(placement: .primaryAction) {
            Button {
                addDeviceButtonActive.toggle()
            } label: {
                Label("Add Device", systemImage: "plus")
            }
            .keyboardShortcut("n", modifiers: .command)
        }
        
        ToolbarItem(placement: .automatic) {
            Menu {
                Section {
                    visibilityButton
                    hideOfflineButton
                }
                
                Divider()
                
                Section {
                    Button("Refresh All Devices") {
                        Task {
                            await refreshList()
                        }
                    }
                    .keyboardShortcut("r", modifiers: .command)
                    
                    Button("Discover WLED Devices") {
                        Task {
                            await discoveryService.scan()
                        }
                    }
                    .keyboardShortcut("d", modifiers: [.command, .shift])
                    
                    Button("Subnet Discovery") {
                        subnetDiscoveryActive = true
                    }
                    .keyboardShortcut("s", modifiers: [.command, .shift])
                }
                
                Divider()
                
                Section {
                    Link(destination: URL(string: "https://kno.wled.ge/")!) {
                        Label("WLED Documentation", systemImage: "questionmark.circle")
                    }
                }
            } label: {
                Label("Menu", systemImage: "ellipsis.circle")
            }
        }
    }
    
    var visibilityButton: some View {
        Button {
            withAnimation {
                showHiddenDevices.toggle()
            }
        } label: {
            if (showHiddenDevices) {
                Label("Hide Hidden Devices", systemImage: "eye.slash")
            } else {
                Label("Show Hidden Devices", systemImage: "eye")
            }
        }
    }
    
    var hideOfflineButton: some View {
        Button {
            withAnimation {
                showOfflineDevices.toggle()
            }
        } label: {
            if (showOfflineDevices) {
                Label("Hide Offline Devices", systemImage: "wifi")
            } else {
                Label("Show Offline Devices", systemImage: "wifi.slash")
            }
        }
    }
    
    //MARK: - Actions
    
    @Sendable
    private func refreshList() async {
        await withTaskGroup(of: Void.self) { group in
            group.addTask { await discoveryService.scan() }
            group.addTask { await refreshDevices() }
        }
    }
    
    private func updateFilter() {
        print("Update Filter")
        if showHiddenDevices {
            devices.nsPredicate = NSPredicate(format: "isOnline == %@", NSNumber(value: true))
            devicesOffline.nsPredicate =  NSPredicate(format: "isOnline == %@", NSNumber(value: false))
        } else {
            devices.nsPredicate = NSPredicate(format: "isOnline == %@ AND isHidden == %@", NSNumber(value: true), NSNumber(value: false))
            devicesOffline.nsPredicate =  NSPredicate(format: "isOnline == %@ AND isHidden == %@", NSNumber(value: false), NSNumber(value: false))
        }
    }
    
    //  Instead of using a timer, use the WebSocket API to get notified about changes
    //  Cancel the connection if the view disappears and reconnect as soon it apears again
    private func appearAction() {
        updateFilter()
        timer = Timer.scheduledTimer(withTimeInterval: 30, repeats: true) { _ in
            Task {
                print("auto-refreshing")
                await refreshList()
                await refreshDevices()
            }
        }
        discoveryService.scan()
    }
    
    private func disappearAction() {
        timer?.invalidate()
    }
    
    @Sendable
    private func refreshDevices() async {
        await withTaskGroup(of: Void.self) { group in
            devices.forEach { refreshDevice(device: $0, group: &group) }
            devicesOffline.forEach { refreshDevice(device: $0, group: &group) }
        }
    }
    
    private func refreshDevice(device: Device, group: inout TaskGroup<Void>) {
        // Don't start a refresh request when the device is already refreshing.
        if (device.isRefreshing) {
            return
        }
        group.addTask {
            await self.viewContext.performAndWait {
                device.isRefreshing = true
            }
            await device.requestManager.addRequest(WLEDRefreshRequest(context: viewContext))
        }
    }
    
    private func deleteItems(device: Device) {
        withAnimation {
            viewContext.delete(device)
            do {
                if viewContext.hasChanges {
                    try viewContext.save()
                }
            } catch {
                // Replace this implementation with code to handle the error appropriately.
                // fatalError() causes the application to generate a crash log and terminate. You should not use this function in a shipping application, although it may be useful during development.
                let nsError = error as NSError
                fatalError("Unresolved error \(nsError), \(nsError.userInfo)")
            }
        }
    }
}

@available(macOS 13, *)
#Preview("macOS 13") {
    DeviceListView()
            .environment(\.managedObjectContext, PersistenceController.preview.container.viewContext)
            .environmentObject(AppState.shared)
}

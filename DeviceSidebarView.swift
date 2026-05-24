import SwiftUI

// MARK: - Device Sidebar
struct DeviceSidebarView: View {
    @EnvironmentObject var viewModel: WakeOnLANViewModel
    @State private var searchText = ""

    var filteredDevices: [SavedDevice] {
        if searchText.isEmpty {
            return viewModel.savedDevices
        } else {
            return viewModel.savedDevices.filter { device in
                device.name.localizedCaseInsensitiveContains(searchText) ||
                device.macAddress.localizedCaseInsensitiveContains(searchText)
            }
        }
    }

    /// Bridges the native List selection to the view model's selected device.
    private var selection: Binding<UUID?> {
        Binding(
            get: { viewModel.selectedDevice?.id },
            set: { id in
                withAnimation(.easeInOut(duration: 0.15)) {
                    viewModel.selectedDevice = viewModel.savedDevices.first { $0.id == id }
                }
                viewModel.triggerHaptic(.selection)
            }
        )
    }

    var body: some View {
        List(selection: selection) {
            Section {
                ForEach(filteredDevices) { device in
                    DeviceRowView(device: device)
                    .tag(device.id)
                    .contextMenu {
                        DeviceContextMenu(device: device)
                            .environmentObject(viewModel)
                    }
                }
            } header: {
                Text("\(viewModel.savedDevices.count) Saved")
            }
        }
        .listStyle(.sidebar)
        .navigationTitle("Devices")
        .searchable(text: $searchText, placement: .sidebar, prompt: "Search devices")
        .overlay {
            if filteredDevices.isEmpty {
                EmptyDeviceListView(hasDevices: !viewModel.savedDevices.isEmpty)
            }
        }
        .safeAreaInset(edge: .bottom) {
            StatusFooterView()
                .padding(.horizontal, 16)
                .padding(.vertical, 10)
                .background(.bar)
        }
        .sheet(isPresented: $viewModel.isPresentingAddDevice) {
            AddDeviceSheet()
                .environmentObject(viewModel)
        }
    }
}

// MARK: - Device Row
struct DeviceRowView: View {
    let device: SavedDevice
    @State private var isHovered = false
    @EnvironmentObject var viewModel: WakeOnLANViewModel
    
    var body: some View {
        HStack(spacing: 12) {
            // Device type icon in a tinted rounded square
            ZStack {
                RoundedRectangle(cornerRadius: 7, style: .continuous)
                    .fill(Color.accentColor.opacity(0.12))
                    .frame(width: 30, height: 30)

                Image(systemName: device.deviceType.icon)
                    .font(.system(size: 14, weight: .medium))
                    .foregroundStyle(Color.accentColor)
                    .symbolRenderingMode(.hierarchical)
            }

            VStack(alignment: .leading, spacing: 2) {
                Text(device.name)
                    .font(.body)
                    .foregroundColor(.textPrimary)
                    .lineLimit(1)

                Text(device.macAddress)
                    .font(.system(size: 11, design: .monospaced))
                    .foregroundColor(.textSecondary)
                    .lineLimit(1)
            }

            Spacer(minLength: 8)

            // Wake button (revealed on hover)
            if isHovered {
                Button {
                    viewModel.wakeDevice(device)
                    viewModel.triggerHaptic(.medium)
                } label: {
                    Image(systemName: "bolt.fill")
                        .font(.system(size: 12))
                }
                .buttonStyle(.borderless)
                .help("Wake \(device.name)")
                .transition(.scale.combined(with: .opacity))
            }

            // Status dot
            DeviceStatusIndicator(device: device)
        }
        .padding(.vertical, 4)
        .contentShape(Rectangle())
        .onHover { hovering in
            withAnimation(.easeInOut(duration: 0.15)) {
                isHovered = hovering
            }
        }
    }
}

// MARK: - Device Status Indicator
struct DeviceStatusIndicator: View {
    let device: SavedDevice
    @State private var isPulsing = false
    @EnvironmentObject var viewModel: WakeOnLANViewModel
    
    var body: some View {
        ZStack {
            // Outer ring for emphasis
            Circle()
                .fill(statusColor.opacity(0.2))
                .frame(width: 16, height: 16)
            
            // Main status indicator
            Circle()
                .fill(statusColor)
                .frame(width: 10, height: 10)
            
            // Pulsing effect for online devices
            if device.isOnline {
                Circle()
                    .fill(Color.successGreen)
                    .frame(width: 8, height: 8)
                    .scaleEffect(isPulsing ? 1.3 : 1.0)
                    .opacity(isPulsing ? 0.4 : 1.0)
                    .animation(
                        .easeInOut(duration: 1.8).repeatForever(autoreverses: true),
                        value: isPulsing
                    )
                    .onAppear {
                        isPulsing = true
                    }
            }
            
            // Checking indicator
            if viewModel.isCheckingDeviceStatus {
                Circle()
                    .fill(Color.primaryBlue.opacity(0.3))
                    .frame(width: 12, height: 12)
                    .scaleEffect(isPulsing ? 1.2 : 1.0)
                    .animation(
                        .easeInOut(duration: 0.8).repeatForever(autoreverses: true),
                        value: isPulsing
                    )
            }
        }
        .onTapGesture {
            // Manual status check on tap
            viewModel.forceCheckDeviceStatus(device)
            viewModel.triggerHaptic(.light)
        }
        .help(helpText)
    }
    
    private var statusColor: Color {
        if viewModel.isCheckingDeviceStatus {
            return .primaryBlue
        }
        return device.isOnline ? .successGreen : .errorRed
    }
    
    private var helpText: String {
        if viewModel.isCheckingDeviceStatus {
            return "Checking device status..."
        }
        
        let statusText = device.isOnline ? "Online" : "Offline"
        let lastCheck = device.lastStatusCheck?.formatted(date: .omitted, time: .shortened) ?? "Never"
        return "\(device.name) is \(statusText)\nLast checked: \(lastCheck)\nTap to check now"
    }
}

// MARK: - Empty State
struct EmptyDeviceListView: View {
    let hasDevices: Bool
    
    var body: some View {
        VStack(spacing: 16) {
            Image(systemName: hasDevices ? "magnifyingglass" : "network.slash")
                .font(.system(size: 32))
                .foregroundColor(.textSecondary)
                .symbolRenderingMode(.hierarchical)
            
            VStack(spacing: 4) {
                Text(hasDevices ? "No matching devices" : "No devices added")
                    .font(.headline)
                    .foregroundColor(.textPrimary)
                
                Text(hasDevices ? "Try a different search term" : "Add your first device to get started")
                    .font(.subheadline)
                    .foregroundColor(.textSecondary)
                    .multilineTextAlignment(.center)
            }
        }
        .padding(40)
    }
}

// MARK: - Context Menu
struct DeviceContextMenu: View {
    let device: SavedDevice
    @EnvironmentObject var viewModel: WakeOnLANViewModel
    
    var body: some View {
        Button {
            viewModel.wakeDevice(device)
        } label: {
            Label("Wake Device", systemImage: "bolt.fill")
        }
        
        Button {
            viewModel.forceCheckDeviceStatus(device)
        } label: {
            Label("Check Status", systemImage: "magnifyingglass")
        }
        
        Button {
            viewModel.selectDevice(device)
        } label: {
            Label("Select", systemImage: "checkmark.circle")
        }
        
        Divider()
        
        Button(role: .destructive) {
            viewModel.deleteDevice(device)
        } label: {
            Label("Delete", systemImage: "trash")
        }
    }
}

// MARK: - Status Footer
struct StatusFooterView: View {
    @EnvironmentObject var viewModel: WakeOnLANViewModel
    
    var body: some View {
        VStack(spacing: 8) {
            HStack {
                Image(systemName: statusIcon)
                    .foregroundColor(.textSecondary)
                    .font(.caption)

                Text(statusText)
                    .font(.caption)
                    .foregroundColor(.textSecondary)

                Spacer()
                
                if viewModel.isNetworkActive {
                    NetworkActivityIndicator(isActive: viewModel.isNetworkActive)
                }
                
                if viewModel.isCheckingDeviceStatus {
                    HStack(spacing: 4) {
                        ProgressView()
                            .progressViewStyle(CircularProgressViewStyle(tint: .primaryBlue))
                            .scaleEffect(0.6)
                        
                        Text("Checking devices...")
                            .font(.caption2)
                            .foregroundColor(.primaryBlue)
                    }
                }
            }
        }
    }
    
    private var statusIcon: String {
        if viewModel.isCheckingDeviceStatus {
            return "magnifyingglass"
        } else if viewModel.isNetworkActive {
            return "wifi"
        } else {
            return "info.circle"
        }
    }
    
    private var statusText: String {
        if viewModel.isCheckingDeviceStatus {
            return "Checking device connectivity..."
        } else {
            let onlineCount = viewModel.savedDevices.filter { $0.isOnline }.count
            let totalCount = viewModel.savedDevices.count
            
            if totalCount == 0 {
                return viewModel.statusMessage
            } else {
                return "\(onlineCount)/\(totalCount) devices online • \(viewModel.statusMessage)"
            }
        }
    }
}
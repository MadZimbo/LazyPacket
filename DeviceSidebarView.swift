import SwiftUI

// MARK: - Device Sidebar
struct DeviceSidebarView: View {
    @EnvironmentObject var viewModel: WakeOnLANViewModel
    @State private var searchText = ""
    @State private var showingAddDevice = false
    
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
    
    var body: some View {
        VStack(spacing: 0) {
            // Header
            VStack(spacing: 16) {
                HStack {
                    Image(systemName: "network")
                        .foregroundColor(.primaryBlue)
                        .font(.title2)
                        .symbolRenderingMode(.hierarchical)
                    
                    VStack(alignment: .leading, spacing: 2) {
                        Text("Devices")
                            .font(.title2)
                            .fontWeight(.semibold)
                            .foregroundColor(.textPrimary)
                        
                        Text("\(viewModel.savedDevices.count) saved")
                            .font(.caption)
                            .foregroundColor(.textSecondary)
                    }
                    
                    Spacer()
                    
                    Button {
                        showingAddDevice = true
                        viewModel.triggerHaptic(.light)
                    } label: {
                        Image(systemName: "plus.circle.fill")
                            .font(.title3)
                            .foregroundColor(.primaryBlue)
                            .symbolRenderingMode(.hierarchical)
                    }
                    .buttonStyle(.plain)
                    .help("Add new device")
                    
                    Button {
                        viewModel.checkAllDeviceStatus()
                        viewModel.triggerHaptic(.light)
                    } label: {
                        Image(systemName: viewModel.isCheckingDeviceStatus ? "arrow.clockwise" : "arrow.clockwise.circle")
                            .font(.title3)
                            .foregroundColor(.primaryBlue)
                            .symbolRenderingMode(.hierarchical)
                            .rotationEffect(.degrees(viewModel.isCheckingDeviceStatus ? 360 : 0))
                            .animation(
                                viewModel.isCheckingDeviceStatus ? 
                                .linear(duration: 1.0).repeatForever(autoreverses: false) : .default,
                                value: viewModel.isCheckingDeviceStatus
                            )
                    }
                    .buttonStyle(.plain)
                    .help("Refresh device status")
                    .disabled(viewModel.isCheckingDeviceStatus)
                }
                
                // Search bar
                SearchBar(text: $searchText)
            }
            .padding(.horizontal, 20)
            .padding(.top, 20)
            .padding(.bottom, 16)
            
            Divider()
                .background(Color.borderColor)
            
            // Device list
            if filteredDevices.isEmpty {
                EmptyDeviceListView(hasDevices: !viewModel.savedDevices.isEmpty)
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
            } else {
                ScrollView {
                    LazyVStack(spacing: 8) {
                        ForEach(filteredDevices) { device in
                            DeviceRowView(
                                device: device,
                                isSelected: viewModel.selectedDevice?.id == device.id
                            )
                            .onTapGesture {
                                withAnimation(.easeInOut(duration: 0.2)) {
                                    viewModel.selectDevice(device)
                                }
                                viewModel.triggerHaptic(.selection)
                            }
                            .contextMenu {
                                DeviceContextMenu(device: device)
                                    .environmentObject(viewModel)
                            }
                        }
                    }
                    .padding(.horizontal, 20)
                    .padding(.vertical, 16)
                }
            }
            
            Spacer()
            
            // Status footer
            StatusFooterView()
                .padding(.horizontal, 20)
                .padding(.bottom, 20)
        }
        .background(Color.cardBackground)
        .sheet(isPresented: $showingAddDevice) {
            AddDeviceSheet()
                .environmentObject(viewModel)
        }
    }
}

// MARK: - Search Bar
struct SearchBar: View {
    @Binding var text: String
    @FocusState private var isFocused: Bool
    
    var body: some View {
        HStack(spacing: 8) {
            Image(systemName: "magnifyingglass")
                .foregroundColor(.textSecondary)
                .font(.system(size: 14))
            
            TextField("Search devices...", text: $text)
                .textFieldStyle(.plain)
                .font(.system(size: 14))
                .foregroundColor(.textPrimary)
                .focused($isFocused)
            
            if !text.isEmpty {
                Button {
                    text = ""
                } label: {
                    Image(systemName: "xmark.circle.fill")
                        .foregroundColor(.textSecondary)
                        .font(.system(size: 14))
                }
                .buttonStyle(.plain)
            }
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 8)
        .background(Color.appBackground)
        .cornerRadius(8)
        .overlay(
            RoundedRectangle(cornerRadius: 8)
                .stroke(isFocused ? Color.primaryBlue : Color.borderColor, lineWidth: 1)
        )
    }
}

// MARK: - Device Row
struct DeviceRowView: View {
    let device: SavedDevice
    let isSelected: Bool
    @State private var isHovered = false
    @EnvironmentObject var viewModel: WakeOnLANViewModel
    
    var body: some View {
        HStack(spacing: 12) {
            // Device status indicator
            DeviceStatusIndicator(device: device)
            
            VStack(alignment: .leading, spacing: 4) {
                Text(device.name)
                    .font(.system(size: 14, weight: .medium))
                    .foregroundColor(.textPrimary)
                    .lineLimit(1)
                
                Text(device.macAddress)
                    .font(.system(size: 12, weight: .regular, design: .monospaced))
                    .foregroundColor(.textSecondary)
                    .lineLimit(1)
            }
            
            Spacer()
            
            // Wake button (visible on hover or selection)
            if isHovered || isSelected {
                Button {
                    viewModel.wakeDevice(device)
                    viewModel.triggerHaptic(.medium)
                } label: {
                    Image(systemName: "bolt.fill")
                        .font(.system(size: 12))
                        .foregroundColor(.primaryBlue)
                }
                .buttonStyle(.plain)
                .help("Wake \(device.name)")
                .transition(.scale.combined(with: .opacity))
            }
            
            if isSelected {
                Image(systemName: "checkmark.circle.fill")
                    .foregroundColor(.primaryBlue)
                    .font(.system(size: 16))
                    .symbolRenderingMode(.hierarchical)
            }
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 12)
        .background(
            RoundedRectangle(cornerRadius: 12)
                .fill(backgroundFill)
        )
        .overlay(
            RoundedRectangle(cornerRadius: 12)
                .stroke(borderColor, lineWidth: isSelected ? 1 : 0)
        )
        .onHover { hovering in
            withAnimation(.easeInOut(duration: 0.15)) {
                isHovered = hovering
            }
        }
        .scaleEffect(isHovered && !isSelected ? 1.02 : 1.0)
        .animation(.easeInOut(duration: 0.15), value: isHovered)
    }
    
    private var backgroundFill: Color {
        if isSelected {
            return .primaryBlue.opacity(0.15)
        } else if isHovered {
            return .borderColor.opacity(0.5)
        } else {
            return .clear
        }
    }
    
    private var borderColor: Color {
        isSelected ? .primaryBlue : .clear
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
            Divider()
                .background(Color.borderColor)
            
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
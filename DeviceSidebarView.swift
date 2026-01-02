import SwiftUI

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
    
    var body: some View {
        ZStack {
            Circle()
                .fill(device.isOnline ? Color.successGreen : Color.borderColor)
                .frame(width: 12, height: 12)
            
            if device.isOnline {
                Circle()
                    .fill(Color.successGreen)
                    .frame(width: 8, height: 8)
                    .scaleEffect(isPulsing ? 1.2 : 1.0)
                    .opacity(isPulsing ? 0.6 : 1.0)
                    .animation(
                        .easeInOut(duration: 1.5).repeatForever(autoreverses: true),
                        value: isPulsing
                    )
                    .onAppear {
                        isPulsing = true
                    }
            }
        }
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
                Image(systemName: "info.circle")
                    .foregroundColor(.textSecondary)
                    .font(.caption)
                
                Text(viewModel.statusMessage)
                    .font(.caption)
                    .foregroundColor(.textSecondary)
                
                Spacer()
                
                if viewModel.isNetworkActive {
                    NetworkActivityIndicator(isActive: viewModel.isNetworkActive)
                }
            }
        }
    }
}
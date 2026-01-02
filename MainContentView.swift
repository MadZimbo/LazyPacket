import SwiftUI

// MARK: - Main Content View
struct MainContentView: View {
    @EnvironmentObject var viewModel: WakeOnLANViewModel
    
    var body: some View {
        ScrollView {
            VStack(spacing: 32) {
                // Header Section
                HeaderSection()
                
                // Wake Controls Card
                WakeControlsCard()
                
                // Activity Log Card
                ActivityLogCard()
                
                Spacer(minLength: 50)
            }
            .padding(32)
        }
        .background(Color.appBackground)
    }
}

// MARK: - Header Section
struct HeaderSection: View {
    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            HStack(spacing: 16) {
                // App Icon
                ZStack {
                    RoundedRectangle(cornerRadius: 16)
                        .fill(
                            LinearGradient(
                                gradient: Gradient(colors: [
                                    Color.primaryBlue,
                                    Color.primaryBlue.opacity(0.8)
                                ]),
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing
                            )
                        )
                        .frame(width: 64, height: 64)
                    
                    Image(systemName: "bolt.fill")
                        .font(.system(size: 32, weight: .bold))
                        .foregroundColor(.white)
                }
                .shadow(color: .primaryBlue.opacity(0.3), radius: 12, x: 0, y: 4)
                
                VStack(alignment: .leading, spacing: 4) {
                    Text("LazyPacket")
                        .font(.largeTitle)
                        .fontWeight(.bold)
                        .foregroundColor(.textPrimary)
                    
                    Text("Wake-on-LAN Utility")
                        .font(.title3)
                        .foregroundColor(.textSecondary)
                    
                    Text("Send magic packets to wake up network devices")
                        .font(.subheadline)
                        .foregroundColor(.textSecondary)
                }
                
                Spacer()
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }
}

// MARK: - Wake Controls Card
struct WakeControlsCard: View {
    @EnvironmentObject var viewModel: WakeOnLANViewModel
    @State private var macAddress = ""
    @State private var deviceName = ""
    @State private var isValidMAC = false
    @State private var isEditing = false
    @FocusState private var macFieldIsFocused: Bool
    
    var body: some View {
        VStack(spacing: 24) {
            // Card Header
            HStack {
                Label("Send Magic Packet", systemImage: "bolt.circle.fill")
                    .font(.headline)
                    .foregroundColor(.textPrimary)
                
                Spacer()
                
                if viewModel.selectedDevice != nil {
                    Button("Clear Selection") {
                        viewModel.selectedDevice = nil
                        clearFields()
                        viewModel.triggerHaptic(.light)
                    }
                    .buttonStyle(.plain)
                    .foregroundColor(.primaryBlue)
                    .font(.caption)
                }
            }
            
            VStack(spacing: 20) {
                // Selected Device Info
                if let selectedDevice = viewModel.selectedDevice {
                    SelectedDeviceView(device: selectedDevice, onUseMAC: {
                        macAddress = selectedDevice.macAddress
                        deviceName = selectedDevice.name
                        validateMAC()
                    }, onSendPacket: {
                        sendWakePacket()
                    })
                }
                
                // Input Fields
                VStack(alignment: .leading, spacing: 16) {
                    // MAC Address Field
                    VStack(alignment: .leading, spacing: 8) {
                        Text("MAC Address")
                            .font(.subheadline)
                            .fontWeight(.medium)
                            .foregroundColor(.textSecondary)
                        
                        TextField("AA:BB:CC:DD:EE:FF", text: $macAddress)
                            .textFieldStyle(ModernTextFieldStyle(isValid: macAddress.isEmpty ? nil : isValidMAC))
                            .focused($macFieldIsFocused)
                            .onChange(of: macAddress) {
                                validateMAC()
                            }
                            .onSubmit {
                                if isValidMAC {
                                    sendWakePacket()
                                }
                            }
                    }
                    
                    // Device Name Field (for adding new devices)
                    VStack(alignment: .leading, spacing: 8) {
                        Text(isEditing ? "Device Name" : "Device Name (Optional)")
                            .font(.subheadline)
                            .fontWeight(.medium)
                            .foregroundColor(.textSecondary)
                        
                        TextField("My Computer", text: $deviceName)
                            .textFieldStyle(ModernTextFieldStyle())
                    }
                }
                
                // Action Buttons
                HStack(spacing: 16) {
                    // Add/Save Device Button
                    Button {
                        if isEditing {
                            saveDeviceChanges()
                        } else {
                            addDevice()
                        }
                    } label: {
                        HStack {
                            Image(systemName: isEditing ? "checkmark.circle.fill" : "plus.circle.fill")
                            Text(isEditing ? "Save Changes" : "Add Device")
                        }
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 12)
                    }
                    .buttonStyle(ModernButtonStyle(isEditing ? .primary : .secondary))
                    .disabled(!isValidMAC || deviceName.isEmpty)
                    
                    // Delete Device Button (only visible when editing)
                    if isEditing {
                        Button {
                            deleteSelectedDevice()
                        } label: {
                            HStack {
                                Image(systemName: "trash.fill")
                                Text("Delete")
                            }
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 12)
                        }
                        .buttonStyle(ModernButtonStyle(.danger))
                    }
                    
                    // Wake Button (only show when no device is selected)
                    if viewModel.selectedDevice == nil {
                        Button {
                            sendWakePacket()
                        } label: {
                            HStack {
                                if viewModel.isSending {
                                    ProgressView()
                                        .scaleEffect(0.8)
                                        .progressViewStyle(CircularProgressViewStyle(tint: .white))
                                } else {
                                    Image(systemName: "bolt.fill")
                                        .scaleEffect(isValidMAC ? 1.1 : 1.0)
                                        .animation(.easeInOut(duration: 0.6).repeatForever(autoreverses: true), value: isValidMAC)
                                }
                                Text(viewModel.isSending ? "Sending..." : "Send Magic Packet")
                            }
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 12)
                        }
                        .buttonStyle(ModernButtonStyle(.primary))
                        .disabled(!isValidMAC || viewModel.isSending)
                        .keyboardShortcut(.return, modifiers: [])
                    }
                }
            }
        }
        .padding(24)
        .background(CardBackground())
        .onAppear {
            updateFieldsFromSelection()
        }
        .onChange(of: viewModel.selectedDevice) { _, newDevice in
            updateFieldsFromSelection()
        }
    }
    
    private func validateMAC() {
        isValidMAC = WakeOnLANViewModel.isValidMACAddress(macAddress)
    }
    
    private func updateFieldsFromSelection() {
        if let selectedDevice = viewModel.selectedDevice {
            macAddress = selectedDevice.macAddress
            deviceName = selectedDevice.name
            isEditing = true
            validateMAC()
        } else {
            isEditing = false
        }
    }
    
    private func sendWakePacket() {
        guard isValidMAC else { return }
        
        viewModel.sendWakePacket(to: macAddress, deviceName: deviceName.isEmpty ? nil : deviceName)
        viewModel.triggerHaptic(.medium)
        
        // Add visual feedback
        withAnimation(.easeInOut(duration: 0.3)) {
            macFieldIsFocused = false
        }
    }
    
    private func addDevice() {
        guard isValidMAC, !deviceName.isEmpty, !isEditing else { return }
        
        let device = SavedDevice(
            name: deviceName,
            macAddress: macAddress,
            isOnline: false
        )
        
        viewModel.addDevice(device)
        clearFields()
        viewModel.triggerHaptic(.success)
    }
    
    private func saveDeviceChanges() {
        guard let selectedDevice = viewModel.selectedDevice,
              isValidMAC, !deviceName.isEmpty, isEditing else { return }
        
        viewModel.updateDevice(selectedDevice, name: deviceName, macAddress: macAddress)
        viewModel.triggerHaptic(.success)
    }
    
    private func deleteSelectedDevice() {
        guard let selectedDevice = viewModel.selectedDevice else { return }
        
        viewModel.deleteDevice(selectedDevice)
        clearFields()
        viewModel.triggerHaptic(.warning)
    }
    
    private func clearFields() {
        macAddress = ""
        deviceName = ""
        isValidMAC = false
        isEditing = false
    }
}

// MARK: - Selected Device View
struct SelectedDeviceView: View {
    let device: SavedDevice
    let onUseMAC: () -> Void
    let onSendPacket: () -> Void
    @EnvironmentObject var viewModel: WakeOnLANViewModel
    
    var body: some View {
        HStack {
            DeviceStatusIndicator(device: device)
            
            VStack(alignment: .leading, spacing: 2) {
                Text("Selected: \(device.name)")
                    .font(.subheadline)
                    .fontWeight(.medium)
                    .foregroundColor(.textPrimary)
                
                Text(device.macAddress)
                    .font(.caption)
                    .fontDesign(.monospaced)
                    .foregroundColor(.textSecondary)
            }
            
            Spacer()
            
            Button {
                onSendPacket()
            } label: {
                HStack(spacing: 6) {
                    if viewModel.isSending {
                        ProgressView()
                            .scaleEffect(0.7)
                            .progressViewStyle(CircularProgressViewStyle(tint: .white))
                    } else {
                        Image(systemName: "bolt.fill")
                            .font(.caption)
                    }
                    Text(viewModel.isSending ? "Sending..." : "Send Magic Packet")
                        .font(.caption)
                        .fontWeight(.semibold)
                }
                .padding(.horizontal, 12)
                .padding(.vertical, 8)
            }
            .buttonStyle(ModernButtonStyle(.primary, size: .small))
            .disabled(viewModel.isSending)
        }
        .padding(16)
        .background(Color.primaryBlue.opacity(0.1))
        .cornerRadius(12)
        .overlay(
            RoundedRectangle(cornerRadius: 12)
                .stroke(Color.primaryBlue.opacity(0.3), lineWidth: 1)
        )
        .onAppear {
            // Automatically populate fields when device appears
            onUseMAC()
        }
    }
}

// MARK: - Activity Log Card
struct ActivityLogCard: View {
    @EnvironmentObject var viewModel: WakeOnLANViewModel
    
    var body: some View {
        VStack(spacing: 20) {
            HStack {
                Label("Activity Log", systemImage: "clock.fill")
                    .font(.headline)
                    .foregroundColor(.textPrimary)
                
                Spacer()
                
                if !viewModel.activityLog.isEmpty {
                    Button("Clear Log") {
                        withAnimation(.easeInOut) {
                            viewModel.clearActivityLog()
                        }
                        viewModel.triggerHaptic(.light)
                    }
                    .buttonStyle(.plain)
                    .foregroundColor(.textSecondary)
                    .font(.caption)
                }
            }
            
            if viewModel.activityLog.isEmpty {
                EmptyActivityLogView()
            } else {
                ScrollView {
                    LazyVStack(spacing: 8) {
                        ForEach(viewModel.activityLog) { activity in
                            ActivityRowView(activity: activity)
                        }
                    }
                }
                .frame(maxHeight: 200)
            }
        }
        .padding(24)
        .background(CardBackground())
    }
}

// MARK: - Activity Row View
struct ActivityRowView: View {
    let activity: ActivityLogItem
    
    var body: some View {
        HStack(spacing: 12) {
            Image(systemName: activity.icon)
                .foregroundColor(activity.color)
                .frame(width: 16)
                .symbolRenderingMode(.hierarchical)
            
            VStack(alignment: .leading, spacing: 2) {
                Text(activity.message)
                    .font(.system(size: 14))
                    .foregroundColor(.textPrimary)
                    .lineLimit(2)
                    .textSelection(.enabled)
                
                Text(activity.timestamp, style: .time)
                    .font(.caption)
                    .foregroundColor(.textSecondary)
                    .textSelection(.enabled)
            }
            
            Spacer()
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 10)
        .background(Color.appBackground)
        .cornerRadius(8)
        .transition(.asymmetric(
            insertion: .move(edge: .top).combined(with: .opacity),
            removal: .move(edge: .trailing).combined(with: .opacity)
        ))
    }
}

// MARK: - Empty Activity Log
struct EmptyActivityLogView: View {
    var body: some View {
        VStack(spacing: 12) {
            Image(systemName: "clock.fill")
                .font(.system(size: 24))
                .foregroundColor(.textSecondary)
                .symbolRenderingMode(.hierarchical)
            
            Text("No recent activity")
                .font(.subheadline)
                .foregroundColor(.textSecondary)
            
            Text("Wake packet activity will appear here")
                .font(.caption)
                .foregroundColor(.textSecondary)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 32)
    }
}

// MARK: - Card Background
struct CardBackground: View {
    var body: some View {
        RoundedRectangle(cornerRadius: 16)
            .fill(Color.cardBackground)
            .overlay(
                RoundedRectangle(cornerRadius: 16)
                    .stroke(Color.borderColor, lineWidth: 1)
            )
            .shadow(color: .black.opacity(0.1), radius: 8, x: 0, y: 4)
    }
}

// MARK: - Modern Text Field Style
struct ModernTextFieldStyle: TextFieldStyle {
    let isValid: Bool?
    
    init(isValid: Bool? = nil) {
        self.isValid = isValid
    }
    
    func _body(configuration: TextField<Self._Label>) -> some View {
        configuration
            .font(.system(size: 14, design: .monospaced))
            .foregroundColor(.textPrimary)
            .padding(.horizontal, 16)
            .padding(.vertical, 12)
            .background(Color.appBackground)
            .cornerRadius(8)
            .overlay(
                RoundedRectangle(cornerRadius: 8)
                    .stroke(borderColor, lineWidth: 2)
            )
    }
    
    private var borderColor: Color {
        guard let isValid = isValid else { return Color.borderColor }
        return isValid ? Color.successGreen : Color.errorRed
    }
}

// MARK: - Modern Button Style
struct ModernButtonStyle: ButtonStyle {
    enum ButtonType {
        case primary, secondary, danger
    }
    
    enum Size {
        case small, normal, large
    }
    
    let type: ButtonType
    let size: Size
    
    init(_ type: ButtonType, size: Size = .normal) {
        self.type = type
        self.size = size
    }
    
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(fontForSize)
            .foregroundColor(foregroundColor)
            .padding(.horizontal, horizontalPadding)
            .padding(.vertical, verticalPadding)
            .background(backgroundColor)
            .cornerRadius(8)
            .scaleEffect(configuration.isPressed ? 0.95 : 1.0)
            .animation(.easeInOut(duration: 0.1), value: configuration.isPressed)
    }
    
    private var fontForSize: Font {
        switch size {
        case .small: return .caption.weight(.semibold)
        case .normal: return .subheadline.weight(.semibold)
        case .large: return .headline.weight(.semibold)
        }
    }
    
    private var horizontalPadding: CGFloat {
        switch size {
        case .small: return 12
        case .normal: return 16
        case .large: return 20
        }
    }
    
    private var verticalPadding: CGFloat {
        switch size {
        case .small: return 6
        case .normal: return 8
        case .large: return 12
        }
    }
    
    private var backgroundColor: Color {
        switch type {
        case .primary: return .primaryBlue
        case .secondary: return .borderColor
        case .danger: return .errorRed
        }
    }
    
    private var foregroundColor: Color {
        switch type {
        case .primary: return .white
        case .secondary: return .textPrimary
        case .danger: return .white
        }
    }
}
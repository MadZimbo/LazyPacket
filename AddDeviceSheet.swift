import SwiftUI

// MARK: - Add Device Sheet
struct AddDeviceSheet: View {
    @EnvironmentObject var viewModel: WakeOnLANViewModel
    @Environment(\.dismiss) var dismiss
    
    @State private var deviceName = ""
    @State private var macAddress = ""
    @State private var selectedDeviceType: DeviceType = .computer
    @State private var isValidMAC = false
    @FocusState private var nameFieldIsFocused: Bool
    
    var canSave: Bool {
        !deviceName.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty && isValidMAC
    }
    
    var body: some View {
        VStack(spacing: 32) {
            // Header
            VStack(spacing: 16) {
                HStack {
                    Button("Cancel") {
                        dismiss()
                        viewModel.triggerHaptic(.light)
                    }
                    .buttonStyle(.plain)
                    .foregroundColor(.textSecondary)
                    
                    Spacer()
                    
                    Text("Add New Device")
                        .font(.headline)
                        .foregroundColor(.textPrimary)
                    
                    Spacer()
                    
                    Button("Add Device") {
                        saveDevice()
                    }
                    .buttonStyle(ModernButtonStyle(.primary, size: .small))
                    .disabled(!canSave)
                }
                
                Divider()
                    .background(Color.borderColor)
            }
            
            // Device preview
            DevicePreviewCard(
                name: deviceName.isEmpty ? "New Device" : deviceName,
                macAddress: macAddress.isEmpty ? "AA:BB:CC:DD:EE:FF" : macAddress,
                deviceType: selectedDeviceType,
                isValid: canSave
            )
            
            // Form
            VStack(spacing: 24) {
                // Device Type Selection
                VStack(alignment: .leading, spacing: 12) {
                    Text("Device Type")
                        .font(.subheadline)
                        .fontWeight(.medium)
                        .foregroundColor(.textSecondary)
                    
                    LazyVGrid(columns: Array(repeating: GridItem(.flexible()), count: 4), spacing: 12) {
                        ForEach(DeviceType.allCases, id: \.self) { deviceType in
                            DeviceTypeButton(
                                deviceType: deviceType,
                                isSelected: selectedDeviceType == deviceType
                            ) {
                                selectedDeviceType = deviceType
                                viewModel.triggerHaptic(.selection)
                            }
                        }
                    }
                }
                
                // Device Name Field
                VStack(alignment: .leading, spacing: 8) {
                    Text("Device Name")
                        .font(.subheadline)
                        .fontWeight(.medium)
                        .foregroundColor(.textSecondary)
                    
                    TextField("Enter device name", text: $deviceName)
                        .textFieldStyle(ModernTextFieldStyle())
                        .focused($nameFieldIsFocused)
                        .onSubmit {
                            if canSave {
                                saveDevice()
                            }
                        }
                }
                
                // MAC Address Field
                VStack(alignment: .leading, spacing: 8) {
                    Text("MAC Address")
                        .font(.subheadline)
                        .fontWeight(.medium)
                        .foregroundColor(.textSecondary)
                    
                    TextField("AA:BB:CC:DD:EE:FF", text: $macAddress)
                        .textFieldStyle(ModernTextFieldStyle(isValid: macAddress.isEmpty ? nil : isValidMAC))
                        .onChange(of: macAddress) {
                            validateMAC()
                        }
                        .onSubmit {
                            if canSave {
                                saveDevice()
                            }
                        }
                    
                    if !macAddress.isEmpty && !isValidMAC {
                        Label("Please enter a valid MAC address format", systemImage: "exclamationmark.triangle.fill")
                            .font(.caption)
                            .foregroundColor(.errorRed)
                            .symbolRenderingMode(.hierarchical)
                    }
                }
                
                // Tips
                VStack(alignment: .leading, spacing: 8) {
                    Text("Tips")
                        .font(.subheadline)
                        .fontWeight(.medium)
                        .foregroundColor(.textSecondary)
                    
                    VStack(alignment: .leading, spacing: 4) {
                        TipRow(icon: "lightbulb", text: "Find MAC address in network settings or system info")
                        TipRow(icon: "network", text: "Ensure Wake-on-LAN is enabled on target device")
                        TipRow(icon: "wifi", text: "Device must be on the same network segment")
                    }
                }
            }
            
            Spacer()
        }
        .padding(32)
        .frame(width: 600, height: 700)
        .background(Color.cardBackground)
        .onAppear {
            nameFieldIsFocused = true
        }
    }
    
    private func validateMAC() {
        isValidMAC = WakeOnLANViewModel.isValidMACAddress(macAddress)
    }
    
    private func saveDevice() {
        let trimmedName = deviceName.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmedName.isEmpty && isValidMAC else { return }
        
        let device = SavedDevice(
            name: trimmedName,
            macAddress: macAddress.uppercased(),
            isOnline: false,
            deviceType: selectedDeviceType
        )
        
        viewModel.addDevice(device)
        dismiss()
        viewModel.triggerHaptic(.success)
    }
}

// MARK: - Device Preview Card
struct DevicePreviewCard: View {
    let name: String
    let macAddress: String
    let deviceType: DeviceType
    let isValid: Bool
    
    var body: some View {
        VStack(spacing: 16) {
            // Device Icon
            ZStack {
                Circle()
                    .fill(isValid ? Color.primaryBlue.opacity(0.15) : Color.borderColor.opacity(0.1))
                    .frame(width: 80, height: 80)
                
                Image(systemName: deviceType.icon)
                    .font(.system(size: 32, weight: .medium))
                    .foregroundColor(isValid ? .primaryBlue : .textSecondary)
                    .symbolRenderingMode(.hierarchical)
            }
            
            // Device Info
            VStack(spacing: 4) {
                Text(name)
                    .font(.headline)
                    .foregroundColor(.textPrimary)
                    .lineLimit(1)
                
                Text(macAddress)
                    .font(.caption.monospaced())
                    .foregroundColor(.textSecondary)
                    .lineLimit(1)
            }
        }
        .padding(24)
        .background(Color.appBackground)
        .cornerRadius(16)
        .overlay(
            RoundedRectangle(cornerRadius: 16)
                .stroke(isValid ? Color.primaryBlue.opacity(0.3) : Color.borderColor, lineWidth: 1)
        )
    }
}

// MARK: - Device Type Button
struct DeviceTypeButton: View {
    let deviceType: DeviceType
    let isSelected: Bool
    let action: () -> Void
    
    var body: some View {
        Button(action: action) {
            VStack(spacing: 8) {
                Image(systemName: deviceType.icon)
                    .font(.title2)
                    .foregroundColor(isSelected ? .white : .textSecondary)
                    .symbolRenderingMode(.hierarchical)
                
                Text(deviceType.displayName)
                    .font(.caption2)
                    .foregroundColor(isSelected ? .white : .textSecondary)
                    .lineLimit(2)
                    .multilineTextAlignment(.center)
            }
            .frame(height: 80)
            .frame(maxWidth: .infinity)
            .background(isSelected ? Color.primaryBlue : Color.appBackground)
            .cornerRadius(12)
            .overlay(
                RoundedRectangle(cornerRadius: 12)
                    .stroke(isSelected ? Color.primaryBlue : Color.borderColor, lineWidth: 1)
            )
        }
        .buttonStyle(.plain)
    }
}

// MARK: - Tip Row
struct TipRow: View {
    let icon: String
    let text: String
    
    var body: some View {
        HStack(spacing: 8) {
            Image(systemName: icon)
                .foregroundColor(.primaryBlue)
                .font(.caption)
                .frame(width: 12)
                .symbolRenderingMode(.hierarchical)
            
            Text(text)
                .font(.caption)
                .foregroundColor(.textSecondary)
        }
    }
}


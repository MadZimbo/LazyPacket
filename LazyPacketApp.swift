import SwiftUI

@main
struct LazyPacketApp: App {
    // Single shared model so the menu bar commands and the window share state.
    @StateObject private var viewModel = WakeOnLANViewModel()

    var body: some Scene {
        WindowGroup {
            ContentView()
                .environmentObject(viewModel)
        }
        .windowStyle(.hiddenTitleBar)
        .windowToolbarStyle(.unified(showsTitle: false))
        .commands {
            DeviceCommands(viewModel: viewModel)
        }

        #if os(macOS)
        Settings {
            SettingsView()
                .environmentObject(viewModel)
        }
        #endif
    }
}

// MARK: - Menu Bar Commands
/// Wires the Device menu to real actions. Uses an `@ObservedObject` so the
/// Wake/Delete items enable and disable as the selection changes.
struct DeviceCommands: Commands {
    @ObservedObject var viewModel: WakeOnLANViewModel

    var body: some Commands {
        CommandMenu("Device") {
            Button("Add Device…") {
                viewModel.isPresentingAddDevice = true
            }
            .keyboardShortcut("n", modifiers: .command)

            Button("Wake Selected Device") {
                if let device = viewModel.selectedDevice {
                    viewModel.wakeDevice(device)
                }
            }
            // Shift-⌘-W so we don't hijack ⌘W (close window).
            .keyboardShortcut("w", modifiers: [.command, .shift])
            .disabled(viewModel.selectedDevice == nil)

            Button("Refresh All Statuses") {
                viewModel.checkAllDeviceStatus()
            }
            .keyboardShortcut("r", modifiers: .command)
            .disabled(viewModel.isCheckingDeviceStatus)

            Divider()

            Button("Delete Selected Device") {
                if let device = viewModel.selectedDevice {
                    viewModel.deleteDevice(device)
                }
            }
            // ⌘-Delete: the standard "move to trash" shortcut.
            .keyboardShortcut(.delete, modifiers: .command)
            .disabled(viewModel.selectedDevice == nil)
        }
    }
}
// MARK: - About & Support Window
struct SettingsView: View {
    var body: some View {
        AboutTabView()
            .frame(width: 500, height: 500)
    }
}

// MARK: - About Tab
struct AboutTabView: View {
    var body: some View {
        ScrollView {
            VStack(spacing: 32) {
                // App Icon and Info
                VStack(spacing: 16) {
                    AppIconView(size: 96)
                    
                    VStack(spacing: 8) {
                        Text("LazyPacket")
                            .font(.title)
                            .fontWeight(.bold)
                            .foregroundColor(.textPrimary)
                        
                        Text("Version 1.0")
                            .font(.subheadline)
                            .foregroundColor(.textSecondary)
                    }
                    
                    Text("A simple Wake-on-LAN utility to remotely wake up network devices.")
                        .font(.body)
                        .foregroundColor(.textSecondary)
                        .multilineTextAlignment(.center)
                        .padding(.horizontal, 32)
                }
                
                Divider()
                    .background(Color.borderColor)
                    .padding(.horizontal, 32)
                
                // Support Section
                VStack(spacing: 16) {
                    VStack(spacing: 8) {
                        Image(systemName: "heart.circle.fill")
                            .font(.system(size: 32))
                            .foregroundColor(.primaryBlue)
                            .symbolRenderingMode(.hierarchical)
                        
                        Text("Support Development")
                            .font(.headline)
                            .foregroundColor(.textPrimary)
                    }
                    
                    Text("If you enjoy using LazyPacket, consider supporting its development with a small donation.")
                        .font(.body)
                        .foregroundColor(.textSecondary)
                        .multilineTextAlignment(.center)
                        .padding(.horizontal, 32)
                    
                    Button {
                        // PayPal link will be added later
                        if let url = URL(string: "https://paypal.me/yourpaypallink") {
                            #if os(macOS)
                            NSWorkspace.shared.open(url)
                            #endif
                        }
                    } label: {
                        HStack(spacing: 8) {
                            Image(systemName: "gift.fill")
                            Text("Donate via PayPal")
                                .fontWeight(.semibold)
                        }
                        .foregroundColor(.white)
                        .padding(.horizontal, 24)
                        .padding(.vertical, 12)
                        .background(Color.primaryBlue)
                        .cornerRadius(10)
                    }
                    .buttonStyle(.plain)
                }
                
                Divider()
                    .background(Color.borderColor)
                    .padding(.horizontal, 32)
                
                // Features
                VStack(alignment: .leading, spacing: 12) {
                    Text("Features")
                        .font(.headline)
                        .foregroundColor(.textPrimary)
                    
                    AboutFeatureRow(icon: "bolt.fill", text: "Send Wake-on-LAN magic packets")
                    AboutFeatureRow(icon: "network", text: "Manage multiple network devices")
                    AboutFeatureRow(icon: "checkmark.circle.fill", text: "Real-time device status monitoring")
                    AboutFeatureRow(icon: "clock.fill", text: "Activity logging and history")
                }
                .frame(maxWidth: 400)
                
                Spacer()
            }
            .padding(32)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(Color.appBackground)
    }
}

// MARK: - About Feature Row
struct AboutFeatureRow: View {
    let icon: String
    let text: String
    
    var body: some View {
        HStack(spacing: 12) {
            Image(systemName: icon)
                .font(.system(size: 16))
                .foregroundColor(.primaryBlue)
                .symbolRenderingMode(.hierarchical)
                .frame(width: 24)
            
            Text(text)
                .font(.subheadline)
                .foregroundColor(.textSecondary)
            
            Spacer()
        }
    }
}

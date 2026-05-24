import SwiftUI

struct ContentView: View {
    @EnvironmentObject private var viewModel: WakeOnLANViewModel

    var body: some View {
        NavigationSplitView {
            DeviceSidebarView()
                .navigationSplitViewColumnWidth(min: 260, ideal: 300, max: 380)
        } detail: {
            MainContentView()
        }
        .frame(minWidth: 820, minHeight: 580)
        .toolbar {
            ToolbarItem {
                Button {
                    viewModel.isPresentingAddDevice = true
                    viewModel.triggerHaptic(.light)
                } label: {
                    Label("Add Device", systemImage: "plus")
                }
                .help("Add a new device (⌘N)")
            }

            ToolbarItem {
                Button {
                    viewModel.checkAllDeviceStatus()
                    viewModel.triggerHaptic(.light)
                } label: {
                    Label("Refresh Status", systemImage: "arrow.clockwise")
                }
                .help("Refresh device status (⌘R)")
                .disabled(viewModel.isCheckingDeviceStatus)
            }
        }
    }
}

#Preview {
    ContentView()
        .environmentObject(WakeOnLANViewModel())
}

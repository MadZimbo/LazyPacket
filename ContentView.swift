import SwiftUI

struct ContentView: View {
    @StateObject private var viewModel = WakeOnLANViewModel()
    
    var body: some View {
        NavigationSplitView {
            DeviceSidebarView()
                .navigationSplitViewColumnWidth(min: 280, ideal: 320, max: 400)
        } detail: {
            MainContentView()
        }
        .environmentObject(viewModel)
        .frame(minWidth: 800, minHeight: 600)
        .background(Color.appBackground)
        .onAppear {
            // ViewModel automatically loads devices in init()
        }
    }
}

#Preview {
    ContentView()
}
import SwiftUI

@main
struct LazyPacketApp: App {
    var body: some Scene {
        WindowGroup {
            ContentView()
        }
        .windowStyle(.hiddenTitleBar)
        .windowToolbarStyle(.unified(showsTitle: false))
        .commands {
            CommandMenu("Device") {
                Button("Add Device...") {
                    // This will be handled by the view model
                }
                .keyboardShortcut("n", modifiers: .command)
                
                Button("Wake Selected Device") {
                    // This will be handled by the view model
                }
                .keyboardShortcut("w", modifiers: .command)
                
                Divider()
                
                Button("Delete Device") {
                    // This will be handled by the view model
                }
                .keyboardShortcut(.delete)
            }
        }
    }
}
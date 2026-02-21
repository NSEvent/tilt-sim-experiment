import SwiftUI
import AppKit

@main
struct TiltSimApp: App {
    @NSApplicationDelegateAdaptor(AppDelegate.self) var appDelegate
    @StateObject private var appState = AppState()

    var body: some Scene {
        WindowGroup {
            ContentView(appState: appState)
                .frame(minWidth: 960, minHeight: 640)
                .onAppear {
                    appState.startAccelerometer()
                    // Bring window to front
                    NSApplication.shared.activate(ignoringOtherApps: true)
                }
        }
        .defaultSize(width: 960, height: 640)
        .commands {
            CommandGroup(replacing: .pasteboard) {}
            CommandGroup(after: .toolbar) {
                Button("Clear All") {
                    appState.clearGrid()
                }
                .keyboardShortcut(.delete, modifiers: .command)
            }
        }
    }
}

class AppDelegate: NSObject, NSApplicationDelegate {
    func applicationShouldTerminateAfterLastWindowClosed(_ sender: NSApplication) -> Bool {
        true
    }
}

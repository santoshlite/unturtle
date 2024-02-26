import SwiftUI

@main
struct MyApp: App {
    var body: some Scene {
        WindowGroup {
            ContentView()
             .environmentObject(NotificationManager.shared)
        }
    }
}

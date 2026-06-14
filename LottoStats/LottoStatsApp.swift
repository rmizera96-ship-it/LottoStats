import SwiftUI

@main
struct LottoStatsApp: App {
    @UIApplicationDelegateAdaptor(FirebaseAppDelegate.self) private var firebaseAppDelegate

    var body: some Scene {
        WindowGroup {
            ContentView()
        }
    }
}

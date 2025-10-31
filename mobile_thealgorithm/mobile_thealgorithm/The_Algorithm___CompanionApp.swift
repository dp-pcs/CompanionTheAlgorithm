    //___FILEHEADER___

import SwiftUI

@main
struct The_Algorithm_CompanionApp: App {
    var body: some Scene {
        WindowGroup {
            ContentView()
                .onOpenURL { url in
                    print("🌐 SwiftUI App received URL: \(url.absoluteString)")
                    // Post notification for OAuth handling
                    NotificationCenter.default.post(name: .authCallbackReceived, object: url)
                    print("✉️ Posted notification to authCallbackReceived")
                }
        }
    }
}

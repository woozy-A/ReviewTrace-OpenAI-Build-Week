import SwiftUI

@main
struct ReviewTraceApp: App {
    @State private var store = ReviewTraceStore()

    var body: some Scene {
        WindowGroup {
            AppView()
                .environment(store)
        }
    }
}

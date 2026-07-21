import SwiftUI

@main
struct ReviewTraceApp: App {
    @State private var store = ReviewTraceStore()

    var body: some Scene {
        WindowGroup {
            AppView()
                .environment(store)
                // STUDY: This updates SwiftUI system-provided labels and formatting with the in-app language picker.
                .environment(\.locale, store.appLanguage.locale)
        }
    }
}

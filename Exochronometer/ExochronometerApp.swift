import AppIntents
import SwiftData
import SwiftUI

@main
struct ExochronometerApp: App {
    var body: some Scene {
        WindowGroup {
            ContentView()
                .preferredColorScheme(.dark)
        }
        .modelContainer(for: JournalNote.self)
    }
}

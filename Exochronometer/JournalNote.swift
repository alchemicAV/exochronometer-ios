import Foundation
import SwiftData
import ExochronometerCore

@Model
final class JournalNote {
    var noteID: UUID = UUID()
    var timestamp: Date = Date()
    var text: String = ""
    var degrees: [String: Double] = [:]

    init(timestamp: Date = .now, text: String, degrees: [String: Double]) {
        self.noteID = UUID()
        self.timestamp = timestamp
        self.text = text
        self.degrees = degrees
    }

    var snapshot: NoteSnapshot {
        NoteSnapshot(id: noteID, timestamp: timestamp, degrees: degrees)
    }
}

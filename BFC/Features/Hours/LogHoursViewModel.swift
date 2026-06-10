import Foundation
import SwiftData

/// Backs the Log Hours sheet. Manual entry plus voice-to-text into the notes field.
@MainActor
@Observable
final class LogHoursViewModel {
    var date = Date()
    var straightText = "8"
    var overtimeText = "0"
    var doubleText = "0"
    var perDiemReceived = true
    var mealsMissed = 0
    var notes = ""
    var errorMessage: String?

    /// Live speech recognizer; the transcript is merged into `notes`.
    let speech = SpeechTranscriber()
    private var notesBeforeDictation = ""

    private let employer: Employer

    init(employer: Employer) {
        self.employer = employer
        self.perDiemReceived = employer.perDiemRate > 0
    }

    var isRecording: Bool { speech.isRecording }

    /// Start/stop dictation. While recording, notes = prior notes + live transcript.
    func toggleVoice() async {
        if speech.isRecording {
            speech.stop()
        } else {
            notesBeforeDictation = notes.isEmpty ? "" : notes + " "
            speech.reset()
            await speech.start()
        }
    }

    /// Call from the view's onChange of the transcript to mirror it into notes.
    func syncTranscript() {
        guard speech.isRecording || !speech.transcript.isEmpty else { return }
        notes = notesBeforeDictation + speech.transcript
    }

    func save(context: ModelContext) -> Bool {
        guard let straight = Double(straightText),
              let overtime = Double(overtimeText),
              let dbl = Double(doubleText) else {
            errorMessage = "Hours need to be numbers."
            return false
        }
        speech.stop()
        let day = WorkDay(
            date: date,
            straightHours: straight,
            overtimeHours: overtime,
            doubleHours: dbl,
            perDiemReceived: perDiemReceived,
            mealsMissed: mealsMissed,
            notes: notes.trimmingCharacters(in: .whitespacesAndNewlines)
        )
        day.employer = employer
        employer.workDays.append(day)
        context.insert(day)
        do {
            try context.save()
            return true
        } catch {
            errorMessage = "Couldn't save: \(error.localizedDescription)"
            return false
        }
    }
}

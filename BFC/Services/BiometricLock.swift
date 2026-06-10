import Foundation
import LocalAuthentication

/// Gates the Credentials wallet behind Face ID / Touch ID (falls back to the device
/// passcode). If the device has no passcode set we can't lock anything, so we allow
/// access rather than trapping the user out.
@MainActor
@Observable
final class BiometricLock {
    private(set) var isUnlocked = false
    var errorMessage: String?

    /// True only when the device can actually authenticate (passcode/biometry enrolled).
    var canLock: Bool {
        LAContext().canEvaluatePolicy(.deviceOwnerAuthentication, error: nil)
    }

    func unlock() async {
        errorMessage = nil

        #if DEBUG
        // Skip the gate when capturing App Store screenshots in demo mode.
        if ProcessInfo.processInfo.arguments.contains(where: { $0.hasPrefix("-demo") }) {
            isUnlocked = true
            return
        }
        #endif

        // No passcode/biometry on the device — nothing to authenticate against.
        guard canLock else {
            isUnlocked = true
            return
        }

        let context = LAContext()
        context.localizedFallbackTitle = "Use Passcode"
        do {
            let ok = try await context.evaluatePolicy(
                .deviceOwnerAuthentication,
                localizedReason: "Unlock your credentials wallet."
            )
            isUnlocked = ok
        } catch {
            errorMessage = "Couldn't unlock. Tap to try again."
            isUnlocked = false
        }
    }

    func lock() { isUnlocked = false }
}

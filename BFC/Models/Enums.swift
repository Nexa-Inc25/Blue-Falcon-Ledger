import Foundation

/// The lineman's job classification — drives which wage row the analysis applies.
enum LinemanClassification: String, Codable, CaseIterable, Identifiable {
    case journeymanLineman = "Journeyman Lineman"
    case foreman = "Foreman"
    case generalForeman = "General Foreman"
    case equipmentOperator = "Equipment Operator"
    case groundman = "Groundman"
    case cableSplicer = "Cable Splicer"
    case apprentice = "Apprentice Lineman"
    case other = "Other"

    var id: String { rawValue }
}

/// Tax filing status used for rough take-home / dependent context.
enum FilingStatus: String, Codable, CaseIterable, Identifiable {
    case single = "Single"
    case marriedJoint = "Married, Filing Jointly"
    case marriedSeparate = "Married, Filing Separately"
    case headOfHousehold = "Head of Household"

    var id: String { rawValue }
}

/// The kind of document a lineman uploads for a pay period.
enum PayDocumentKind: String, Codable, CaseIterable, Identifiable {
    case payStub = "Pay Stub"
    case neapStatement = "NEAP Statement"
    case timeSheet = "Foreman Time Sheet"
    case other = "Other"

    var id: String { rawValue }

    var systemImage: String {
        switch self {
        case .payStub: return "dollarsign.square"
        case .neapStatement: return "building.columns"
        case .timeSheet: return "list.clipboard"
        case .other: return "doc"
        }
    }
}

/// Role of a chat message in the labor-agreement chat.
enum ChatRole: String, Codable {
    case user
    case assistant
    case system
}

/// Which auth backend the app uses. See CLAUDE.md.
enum AuthBackend: String, Codable, CaseIterable, Identifiable {
    case local = "On-Device"
    case firebase = "Firebase"

    var id: String { rawValue }
}

/// Which LLM backend powers chat + analysis. Switchable in Settings.
enum LLMProvider: String, Codable, CaseIterable, Identifiable {
    case bfcCloud = "BFL Cloud"
    case appleOnDevice = "Apple On-Device"
    case claude = "Claude"
    case openai = "OpenAI"
    case grok = "Grok"

    var id: String { rawValue }

    /// Whether this provider needs an API key stored in the Keychain. BFC Cloud uses a
    /// server-side key (the proxy), and on-device needs none.
    var requiresAPIKey: Bool {
        switch self {
        case .bfcCloud, .appleOnDevice: return false
        case .claude, .openai, .grok: return true
        }
    }

    var systemImage: String {
        switch self {
        case .bfcCloud: return "cloud.fill"
        case .appleOnDevice: return "apple.logo"
        case .claude: return "sparkles"
        case .openai: return "brain"
        case .grok: return "bolt"
        }
    }
}

/// Verdict severity for an analysis result — drives color in the UI.
enum AnalysisVerdict: String, Codable {
    case looksGood = "Looks Good"
    case minor = "Minor Issues"
    case shorted = "You Got Shorted"
    case needsInfo = "Need More Info"
}

import Foundation
import SwiftUI

enum TrafficKind: String, CaseIterable, Identifiable {
    case blocked
    case tracker
    case adRequest
    case adClick
    case tap
    case vault
    case decoy
    case skipped
    case subject
    case page
    case info

    var id: String { rawValue }

    var label: String {
        switch self {
        case .blocked: return "BLOCKED"
        case .tracker: return "TRACKER"
        case .adRequest: return "AD HIT"
        case .adClick: return "EXIT CLICK"
        case .tap: return "TAP"
        case .vault: return "VAULT"
        case .decoy: return "DECOY"
        case .skipped: return "SKIPPED"
        case .subject: return "SUBJECT"
        case .page: return "PAGE"
        case .info: return "INFO"
        }
    }

    var color: Color {
        switch self {
        case .blocked: return Color(red: 1.0, green: 0.27, blue: 0.23)
        case .tracker: return Color(red: 1.0, green: 0.62, blue: 0.04)
        case .adRequest: return Color(red: 1.0, green: 0.84, blue: 0.04)
        case .adClick: return Color(red: 0.75, green: 0.35, blue: 0.95)
        case .tap: return Color(red: 1.0, green: 0.45, blue: 0.75)
        case .vault: return Color(red: 0.55, green: 0.70, blue: 1.0)
        case .decoy: return Color(red: 0.35, green: 0.90, blue: 0.75)
        case .skipped: return Color(red: 1.0, green: 0.55, blue: 0.30)
        case .subject: return Color(red: 1.0, green: 0.72, blue: 0.28)
        case .page: return Color(red: 0.19, green: 0.82, blue: 0.35)
        case .info: return Color(red: 0.39, green: 0.82, blue: 1.0)
        }
    }
}

struct TrafficLogEntry: Identifiable, Equatable {
    let id: UUID
    let timestamp: Date
    let kind: TrafficKind
    let summary: String
    let detail: String
    let pageHost: String?

    init(
        id: UUID = UUID(),
        timestamp: Date = Date(),
        kind: TrafficKind,
        summary: String,
        detail: String,
        pageHost: String? = nil
    ) {
        self.id = id
        self.timestamp = timestamp
        self.kind = kind
        self.summary = summary
        self.detail = detail
        self.pageHost = pageHost
    }
}

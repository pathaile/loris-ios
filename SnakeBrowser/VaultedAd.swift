import Foundation

struct VaultedAd: Identifiable, Codable, Equatable {
    let id: UUID
    let detectedAt: Date
    let pageHost: String?
    let pageURL: String?
    let targetURL: String
    let targetHost: String?
    let source: String
    let titleHint: String?
    let isBillableClickURL: Bool
    var notes: String

    init(
        id: UUID = UUID(),
        detectedAt: Date = Date(),
        pageHost: String?,
        pageURL: String?,
        targetURL: String,
        source: String,
        titleHint: String? = nil,
        notes: String = ""
    ) {
        self.id = id
        self.detectedAt = detectedAt
        self.pageHost = pageHost
        self.pageURL = pageURL
        self.targetURL = targetURL
        self.targetHost = URL(string: targetURL)?.host
        self.source = source
        self.titleHint = titleHint
        self.isBillableClickURL = PaidClickPolicy.isLikelyBillableClickURL(targetURL)
        self.notes = notes
    }
}

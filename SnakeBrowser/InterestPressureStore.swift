import Foundation
import Combine

struct SubjectScore: Identifiable, Equatable {
    let id: String
    let label: String
    var score: Double
    var examples: [String]
}

/// Infers what commercial subjects ads are pushing the user toward.
@MainActor
final class InterestPressureStore: ObservableObject {
    @Published private(set) var scores: [String: Double] = [:]
    @Published private(set) var examples: [String: [String]] = [:]
    @Published private(set) var lastInferredLabel: String?

    private let maxExamples = 4

    var ranked: [SubjectScore] {
        scores
            .map { key, value in
                SubjectScore(
                    id: key,
                    label: Self.label(for: key),
                    score: value,
                    examples: examples[key] ?? []
                )
            }
            .sorted { $0.score > $1.score }
    }

    var dominant: SubjectScore? {
        ranked.first
    }

    var pressureSummary: String {
        guard let dominant else {
            return "No clear ad pressure yet"
        }
        return "Ads pushing: \(dominant.label)"
    }

    func clear() {
        scores.removeAll()
        examples.removeAll()
        lastInferredLabel = nil
    }

    @discardableResult
    func observe(text: String?, url: String?, pageHost: String?, weight: Double = 1.0) -> String? {
        let blob = [text, url, pageHost]
            .compactMap { $0?.lowercased() }
            .joined(separator: " ")
        guard !blob.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else { return nil }

        guard let subject = Self.inferSubject(from: blob) else { return nil }
        scores[subject, default: 0] += weight

        let sample = (text?.trimmingCharacters(in: .whitespacesAndNewlines)).flatMap { $0.isEmpty ? nil : $0 }
            ?? URL(string: url ?? "")?.host
            ?? pageHost
            ?? subject
        var list = examples[subject] ?? []
        if !list.contains(sample) {
            list.insert(String(sample.prefix(80)), at: 0)
            examples[subject] = Array(list.prefix(maxExamples))
        }

        lastInferredLabel = Self.label(for: subject)
        return subject
    }

    /// Decoy category ids that push against the current ad grain.
    func counterDecoyCategoryIDs() -> [String] {
        guard let dominant else {
            return ["science", "gardening", "history", "diy", "cooking", "music", "sports"]
        }
        return Self.counters[dominant.id] ?? ["science", "gardening", "diy"]
    }

    static func label(for key: String) -> String {
        switch key {
        case "telecom": return "Telecom / mobile"
        case "finance": return "Finance / credit"
        case "fashion": return "Fashion / beauty"
        case "food": return "Food / delivery"
        case "gaming": return "Gaming"
        case "auto": return "Auto / vehicles"
        case "travel": return "Travel / lodging"
        case "health": return "Health / fitness"
        case "shopping": return "Retail / shopping"
        case "tech": return "Tech / gadgets"
        case "entertainment": return "Streaming / entertainment"
        case "home": return "Home / real estate"
        case "education": return "Education / careers"
        default: return key.capitalized
        }
    }

    private static let counters: [String: [String]] = [
        "telecom": ["gardening", "science", "cooking", "history"],
        "finance": ["music", "diy", "gardening", "history"],
        "fashion": ["science", "diy", "gardening", "sports"],
        "food": ["sports", "history", "diy", "science"],
        "gaming": ["gardening", "history", "cooking", "music"],
        "auto": ["cooking", "music", "gardening", "science"],
        "travel": ["diy", "science", "cooking", "gardening"],
        "health": ["music", "history", "diy", "cooking"],
        "shopping": ["science", "gardening", "history", "music"],
        "tech": ["cooking", "gardening", "sports", "history"],
        "entertainment": ["science", "diy", "gardening", "cooking"],
        "home": ["music", "sports", "science", "cooking"],
        "education": ["sports", "cooking", "music", "gardening"]
    ]

    private static let keywordMap: [(subject: String, keywords: [String])] = [
        ("telecom", ["t-mobile", "tmobile", "verizon", "at&t", "att ", "mint mobile", "visible", "xfinity mobile", "5g", "unlimited data", "phone plan", "prepaid"]),
        ("finance", ["credit card", "apr", "loan", "mortgage", "bank", "invest", "crypto", "bitcoin", "insurance", "capital one", "amex", "chase", "paypal", "venmo", "robinhood"]),
        ("fashion", ["nike", "adidas", "fashion", "beauty", "skincare", "makeup", "sephora", "lululemon", "apparel", "sneakers", "clothing", "wardrobe"]),
        ("food", ["doordash", "uber eats", "grubhub", "restaurant", "recipe", "grocery", "mcdonald", "starbucks", "pizza", "delivery", "meal kit", "hellofresh"]),
        ("gaming", ["xbox", "playstation", "nintendo", "steam", "epic games", "twitch", "esport", "fortnite", "call of duty", "gaming"]),
        ("auto", ["toyota", "ford", "chevrolet", "tesla", "bmw", "honda", "dealership", "suv", "ev ", "carfax", "auto loan", "vehicle"]),
        ("travel", ["airline", "hotel", "booking.com", "airbnb", "expedia", "tripadvisor", "cruise", "flight", "vacation", "marriott", "hilton"]),
        ("health", ["fitness", "workout", "pharmacy", "supplement", "weight loss", "peloton", "clinic", "dental", "medicare", "wellness"]),
        ("shopping", ["amazon", "walmart", "target", "ebay", "shop now", "free shipping", "discount", "sale", "coupon", "retail"]),
        ("tech", ["iphone", "samsung", "laptop", "gadget", "software", "cloud", "ai ", "chatgpt", "microsoft", "google pixel", "headphones"]),
        ("entertainment", ["netflix", "hulu", "disney+", "spotify", "hbo", "paramount", "streaming", "movie", "concert", "ticketmaster"]),
        ("home", ["real estate", "zillow", "realtor", "apartment", "furniture", "mattress", "home depot", "wayfair", "rent"]),
        ("education", ["university", "degree", "coursera", "udemy", "career", "job", "linkedin learning", "mba", "scholarship"])
    ]

    static func inferSubject(from blob: String) -> String? {
        var best: (String, Int)?
        for entry in keywordMap {
            let hits = entry.keywords.reduce(0) { partial, keyword in
                partial + (blob.contains(keyword) ? 1 : 0)
            }
            if hits > 0 {
                if best == nil || hits > best!.1 {
                    best = (entry.subject, hits)
                }
            }
        }
        return best?.0
    }
}

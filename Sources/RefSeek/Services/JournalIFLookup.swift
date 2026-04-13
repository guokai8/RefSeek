import Foundation

/// Looks up journal impact factors using a bundled JCR database (primary)
/// and OpenAlex Sources API (fallback).
actor JournalIFLookup {
    static let shared = JournalIFLookup()

    /// Bundled IF database: lowercased journal name → {"if": Double, "q": String}
    private let bundledDB: [String: BundledEntry] = {
        struct Entry: Decodable { let `if`: Double; let q: String }
        guard let url = Bundle.module.url(forResource: "journal_if", withExtension: "json", subdirectory: "Resources"),
              let data = try? Data(contentsOf: url),
              let dict = try? JSONDecoder().decode([String: Entry].self, from: data) else {
            return [:]
        }
        return dict.mapValues { BundledEntry(impactFactor: $0.if, quartile: $0.q) }
    }()

    struct BundledEntry {
        let impactFactor: Double
        let quartile: String   // "Q1"-"Q4"
    }

    /// JCR quartile (Q1 = top 25%, Q4 = bottom 25%)
    enum JCRQuartile: String, Comparable {
        case Q1, Q2, Q3, Q4

        static func < (lhs: JCRQuartile, rhs: JCRQuartile) -> Bool {
            lhs.sortOrder < rhs.sortOrder
        }

        var sortOrder: Int {
            switch self { case .Q1: return 1; case .Q2: return 2; case .Q3: return 3; case .Q4: return 4 }
        }

        var color: String {
            switch self { case .Q1: return "red"; case .Q2: return "orange"; case .Q3: return "yellow"; case .Q4: return "gray" }
        }

        /// Estimate quartile from 2yr_mean_citedness (IF proxy).
        /// Thresholds based on typical JCR distribution across all journals:
        ///   Q1 ≥ 5.0, Q2 ≥ 2.0, Q3 ≥ 1.0, Q4 < 1.0
        static func from(impactFactor: Double) -> JCRQuartile {
            if impactFactor >= 5.0 { return .Q1 }
            if impactFactor >= 2.0 { return .Q2 }
            if impactFactor >= 1.0 { return .Q3 }
            return .Q4
        }
    }

    struct JournalInfo {
        let impactFactor: Double?       // JCR IF (bundled) or OpenAlex 2yr_mean_citedness
        let hIndex: Int?
        let isInDOAJ: Bool
        let issnL: String?
        let quartile: JCRQuartile?
        let source: String             // "JCR" or "OpenAlex"
    }

    /// Cache: lowercased journal name → JournalInfo
    private var cache: [String: JournalInfo] = [:]

    /// Lookup by journal display name (e.g. "Nature", "The Lancet")
    func lookup(journalName: String) async -> JournalInfo? {
        let key = journalName.lowercased().trimmingCharacters(in: .whitespacesAndNewlines)
        if key.isEmpty { return nil }

        // Check cache
        if let cached = cache[key] { return cached }

        // ── Phase 1: Check bundled JCR database ──
        if let bundled = bundledDB[key] {
            let q = JCRQuartile(rawValue: bundled.quartile)
            let info = JournalInfo(
                impactFactor: bundled.impactFactor,
                hIndex: nil,
                isInDOAJ: false,
                issnL: nil,
                quartile: q,
                source: "JCR"
            )
            cache[key] = info
            return info
        }

        // ── Phase 2: Fallback to OpenAlex ──
        guard let encoded = key.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed),
              let url = URL(string: "https://api.openalex.org/sources?search=\(encoded)&select=display_name,issn_l,summary_stats,is_in_doaj&per_page=3") else {
            return nil
        }

        var request = URLRequest(url: url)
        request.timeoutInterval = 8
        request.setValue("\(AppConstants.appName)/\(AppConstants.appVersion) (mailto:\(AppConstants.contactEmail))", forHTTPHeaderField: "User-Agent")

        struct SrcResult: Decodable {
            let displayName: String?
            let issnL: String?
            let summaryStats: SummaryStats?
            let isInDoaj: Bool?
            enum CodingKeys: String, CodingKey {
                case displayName = "display_name"
                case issnL = "issn_l"
                case summaryStats = "summary_stats"
                case isInDoaj = "is_in_doaj"
            }
        }
        struct SummaryStats: Decodable {
            let twoYrMeanCitedness: Double?
            let hIndex: Int?
            enum CodingKeys: String, CodingKey {
                case twoYrMeanCitedness = "2yr_mean_citedness"
                case hIndex = "h_index"
            }
        }
        struct SrcResponse: Decodable {
            let results: [SrcResult]?
        }

        do {
            let (data, resp) = try await URLSession.shared.data(for: request)
            guard let http = resp as? HTTPURLResponse, http.statusCode == 200 else { return nil }
            let decoded = try JSONDecoder().decode(SrcResponse.self, from: data)

            guard let results = decoded.results, !results.isEmpty else { return nil }

            let match = results.first { ($0.displayName ?? "").lowercased() == key }
                ?? results.first
            guard let best = match else { return nil }

            // Check bundled DB again with the canonical display name from OpenAlex
            let canonicalKey = (best.displayName ?? key).lowercased()
            if canonicalKey != key, let bundled = bundledDB[canonicalKey] {
                let q = JCRQuartile(rawValue: bundled.quartile)
                let info = JournalInfo(
                    impactFactor: bundled.impactFactor,
                    hIndex: best.summaryStats?.hIndex,
                    isInDOAJ: best.isInDoaj ?? false,
                    issnL: best.issnL,
                    quartile: q,
                    source: "JCR"
                )
                cache[key] = info
                return info
            }

            // Use OpenAlex 2yr_mean_citedness as fallback
            let openAlexIF = best.summaryStats?.twoYrMeanCitedness
            let quartile = openAlexIF.map { JCRQuartile.from(impactFactor: $0) }

            let info = JournalInfo(
                impactFactor: openAlexIF,
                hIndex: best.summaryStats?.hIndex,
                isInDOAJ: best.isInDoaj ?? false,
                issnL: best.issnL,
                quartile: quartile,
                source: "OpenAlex"
            )

            cache[key] = info
            return info
        } catch {
            return nil
        }
    }

    /// Batch lookup for multiple journal names (concurrent, deduplicated)
    func batchLookup(journalNames: [String]) async -> [String: JournalInfo] {
        let unique = Set(journalNames.map { $0.lowercased().trimmingCharacters(in: .whitespacesAndNewlines) })
            .filter { !$0.isEmpty }

        var results: [String: JournalInfo] = [:]

        await withTaskGroup(of: (String, JournalInfo?).self) { group in
            for name in unique {
                group.addTask {
                    let info = await self.lookup(journalName: name)
                    return (name, info)
                }
            }
            for await (name, info) in group {
                if let info { results[name] = info }
            }
        }

        return results
    }

    /// Clear cache
    func clearCache() {
        cache.removeAll()
    }
}

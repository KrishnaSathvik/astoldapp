import Testing
import Foundation
import SwiftData
@testable import Yourly

/// Search scale benchmark (RULES.md §8, "useful at realistic note counts").
///
/// Search is lexical over title + body, so cost is linear in the corpus. These measure the real
/// shape of that cost at 1k / 10k / 25k notes over English, Telugu, Hindi, and mixed-script content,
/// and fail if a change makes it materially worse. Thresholds are deliberately loose — they catch
/// an accidental quadratic or a per-note allocation blowup, not normal machine variance.
@Suite("Search performance")
struct NoteSearchPerformanceTests {

    /// A corpus that exercises the Unicode paths, not just ASCII.
    private static func corpus(count: Int) -> [Note] {
        let templates: [(String?, String)] = [
            ("Alaska trip idea",
             "I keep thinking maybe instead of staying the entire week in Anchorage we could rent a car and drive down toward Seward."),
            (nil,
             "నాకు Alaska trip గురించి ఒక idea వచ్చింది, కానీ Ravi వస్తే Sunday కూడా okay."),
            ("Hyderabad plans",
             "मुझे लगता है कि हमें कल सुबह निकलना चाहिए, वरना traffic बहुत ज़्यादा हो जाएगा."),
            ("Work ideas",
             "New project direction looks promising. Need to research a couple of the tradeoffs before the sync."),
            (nil,
             "నేను actually Saturday better అనిపిస్తుంది, but Tejaswini said Khammam is far."),
        ]
        return (0..<count).map { i in
            let (title, body) = templates[i % templates.count]
            return Note(title: title.map { "\($0) \(i)" },
                        body: "\(body) [\(i)]",
                        createdAt: Date(timeIntervalSince1970: TimeInterval(i)))
        }
    }

    private static func time(_ work: () -> Void) -> TimeInterval {
        let start = Date()
        work()
        return -start.timeIntervalSinceNow
    }

    /// Queries chosen to hit each script, plus one that matches nothing (the worst case: every note
    /// is scanned end to end in both fields).
    private static let queries = ["anchorage", "గురించి", "सुबह", "Tejaswini", "zzzz-no-match"]

    @Test(arguments: [1_000, 10_000, 25_000])
    func filterStaysLinearAtScale(count: Int) {
        let notes = Self.corpus(count: count)
        // Budget scales with the corpus: 25k notes get 25× the 1k allowance. A super-linear
        // regression blows through this; a slower machine does not.
        let budget = 0.12 * (Double(count) / 1_000.0)

        var matched = 0
        let elapsed = Self.time {
            for query in Self.queries {
                matched += searchNotes(notes, query: query).count
            }
        }

        print("[search-bench] \(count) notes × \(Self.queries.count) queries: \(elapsed)s (budget \(budget)s)")
        #expect(matched > 0, "the corpus should match at least some queries")
        #expect(elapsed < budget,
                "searching \(count) notes × \(Self.queries.count) queries took \(elapsed)s (budget \(budget)s)")
    }

    /// The other half of the cost: SwiftData materializing every live note before the filter runs.
    @Test func fetchAndFilterOverTenThousandStoredNotes() throws {
        let container = try NoteStoreContainer.make(inMemory: true)
        let context = ModelContext(container)
        for note in Self.corpus(count: 10_000) { context.insert(note) }
        try context.save()

        let descriptor = FetchDescriptor<Note>(
            predicate: #Predicate { $0.deletedAt == nil },
            sortBy: [SortDescriptor(\.createdAt, order: .reverse)]
        )

        var results = 0
        let elapsed = Self.time {
            let all = (try? context.fetch(descriptor)) ?? []
            results = searchNotes(all, query: "గురించి").count
        }

        print("[search-bench] fetch+filter 10000 stored notes: \(elapsed)s")
        #expect(results == 2_000)   // one in five corpus entries carries the Telugu body
        #expect(elapsed < 1.5, "fetch + filter over 10k stored notes took \(elapsed)s")
    }

    /// Diacritic- and case-insensitivity must survive the scale work.
    @Test func matchingRemainsCaseAndDiacriticInsensitive() {
        let note = Note(title: "Café notes", body: "Meeting at the CAFÉ with Ravi")
        #expect(noteMatches(note, query: "cafe"))
        #expect(noteMatches(note, query: "CAFE"))
        #expect(noteMatches(note, query: "ravi"))
        #expect(!noteMatches(note, query: "zzzz"))
    }
}

import Testing
import Foundation
import UIKit
@testable import Yourly

/// The header rule after a phone keyboard has been at it.
///
/// Reported from a real device: a table showed an extra row reading `—   —`. That row *is* the header
/// rule — iOS smart punctuation rewrites `--` to an en dash and `---` to an em dash as the writer types
/// the third character, so a rule typed on a phone is never stored as the ASCII hyphens the parser was
/// looking for. Read strictly it stopped being a rule and became data: visible, undeletable without
/// breaking the table, and made of characters nobody typed.
///
/// Every test here uses a *typed* spelling. The suite had none — every other table in it is written
/// programmatically by `TableBlock.delimiter(width:)`, which is why this survived.
@MainActor
struct TableSmartDashTests {

    private let spellings = [
        "| --- | --- |",        // what As Told writes
        "| — | — |",            // "---" after smart punctuation
        "| – | – |",            // "--" after smart punctuation
        "| —- | —- |",          // a half-substituted run
        "| :—: | —: |",         // alignment colons survive too
    ]

    @Test func everyTypedSpellingOfTheRuleIsARule() {
        for spelling in spellings {
            #expect(TableBlock.isHeaderRule(spelling), "\(spelling) was not read as a header rule")
        }
    }

    @Test func leniencyIsScopedToTheOneRowARuleCanOccupy() {
        // `isDelimiter` stays strict everywhere else, which is what stops a substituted dash deeper
        // in a table from cutting the table in half.
        #expect(TableBlock.isDelimiter("| --- | --- |"))
        #expect(!TableBlock.isDelimiter("| — | — |"))
    }

    @Test func aSmartDashedRuleDoesNotBecomeARow() {
        let typed = "| Base | Nights |\n| — | — |\n| Anchorage | 3 |"
        let table = TableBlock.tables(in: typed).first
        #expect(table?.hasHeaderRule == true)
        #expect(table?.rows == [["Base", "Nights"], ["Anchorage", "3"]],
                "the rule leaked into the table's rows")
    }

    @Test func theSmartDashedRuleIsHiddenWhileEditing() {
        let typed = "| Base | Nights |\n| — | — |\n| Anchorage | 3 |"
        let storage = NSTextStorage(string: typed)
        StructuredTextStyler.apply(to: storage, textColor: .label)
        let rule = StructuredText.characterRange(ofLines: 1...1, in: typed as NSString)!
        for offset in rule.location..<NSMaxRange(rule) {
            #expect(storage.attribute(.astHiddenMarker, at: offset, effectiveRange: nil) as? Bool == true,
                    "character \(offset) of the rule is still drawn")
        }
    }

    @Test func noSurfaceThatShowsTheNoteAsTextIncludesTheRule() {
        let typed = "| Base | Nights |\n| — | — |\n| Anchorage | 3 |"
        for rendered in [StructuredTextExport.plainText(typed),
                         StructuredTextExport.spokenText(typed),
                         StructuredTextExport.previewText(typed)] {
            #expect(!rendered.contains("—  —"), "the rule reached a reader: \(rendered)")
        }
    }

    @Test func theNotesOwnCharactersAreNeverRewritten() {
        // Recognising a spelling is not correcting it. `body` keeps whatever dash is in it, which is
        // what lets every existing note get this without a migration.
        let typed = "| Base | Nights |\n| — | — |\n| Anchorage | 3 |"
        let storage = NSTextStorage(string: typed)
        StructuredTextStyler.apply(to: storage, textColor: .label)
        #expect(storage.string == typed)
    }

    @Test func aRowOfRealDashesDeeperInTheTableIsStillData() {
        // Only the row immediately after the header is read as the rule, so a table that genuinely
        // uses a dash to mean "no value" keeps it.
        let table = "| Base | Nights |\n| --- | --- |\n| Anchorage | 3 |\n| — | — |"
        #expect(TableBlock.tables(in: table).first?.rows
                == [["Base", "Nights"], ["Anchorage", "3"], ["—", "—"]])
    }

    @Test func proseThatIsJustAnEmDashIsStillProse() {
        #expect(!TableBlock.isDelimiter("—"))
        #expect(!TableBlock.isDelimiter("| words — more |"))
        #expect(TableBlock.tables(in: "A sentence — with an aside.").isEmpty)
    }
}

import SwiftUI
import UIKit
import LinkPresentation
import UniformTypeIdentifiers

// The system share sheet, and nothing of our own around it.
//
// As Told does not draw a destination picker. iOS already knows which apps are installed, which
// contacts are recent, and what this person actually uses — and it knows it without As Told learning
// any of it, which is the version of that feature this app is allowed to have (RULES.md §3). So the
// whole of this file is: build one item, hand it to `UIActivityViewController`, get out of the way.
//
// **One item, two representations.** Not two attachments. A single `NSItemProvider` registers the note
// as UTF-8 text *and* as HTML, and the destination asks for whichever it can use — Mail takes the HTML
// and keeps the links, Messages takes the characters. Sending both as separate items is what produces
// a message with the note in it twice.
enum NoteShareItems {

    /// One provider carrying the note in both representations, built **from the text itself**.
    ///
    /// The provider is initialized *from* an `NSString` rather than started empty and given two data
    /// registrations (changed 2026-08-26). That distinction is not cosmetic: Apple's own
    /// `copyToPasteboard` activity — the sheet's native **Copy** — is documented against direct objects
    /// such as `NSString`, and an all-`registerDataRepresentation` provider did not read as one, so
    /// Copy simply never appeared in the sheet. Same one item, same two representations, same
    /// negotiation; the plain-text side is now an object the system recognises.
    ///
    /// `init(object:)`, **not** `init(item:typeIdentifier:)`. They look interchangeable and are not:
    /// the `item:` initializer wraps the string in a property-list blob, so a destination asking for
    /// `public.utf8-plain-text` gets bytes that are not the note's characters and cannot be coerced
    /// back into a string at all. `NSString` conforms to `NSItemProviderWriting`, so `init(object:)`
    /// registers the real text. `theProviderHandsBackTheBytesThePayloadDescribes` and
    /// `theItemLoadsAsAStringAndNotOnlyAsBytes` both fail under the `item:` form — that is what they
    /// are there to catch.
    ///
    /// This inverts the registration order — plain text is first now, HTML second. Destinations that
    /// name the type they want (Mail asks for HTML) are unaffected; only a destination that takes the
    /// provider's first-listed type would notice, and it gets the note's characters, which is never
    /// wrong, only plainer.
    ///
    /// There is deliberately no As Told **Copy** button anywhere near this. The sheet's Copy is the
    /// system's, for the same reason the destination list is (RULES.md §4, §7).
    static func provider(for payload: NoteSharePayload) -> NSItemProvider {
        let provider = NSItemProvider(object: payload.plainText as NSString)
        // A file name for destinations that ask for one. It is a name, not a path — nothing here
        // writes a file, and no note ever reaches the filesystem on the way out (RULES.md §3).
        provider.suggestedName = payload.sheetTitle.isEmpty ? nil : payload.sheetTitle

        if let html = payload.html {
            provider.registerDataRepresentation(for: .html, visibility: .all) { completion in
                completion(Data(html.utf8), nil)
                return nil
            }
        }
        return provider
    }

    /// What the top of the sheet shows: the app's own icon and the note's name.
    ///
    /// Deliberately **not** an `originalURL`. The obvious way to get a rich header is to hand
    /// `LPLinkMetadata` a URL and let it fetch a preview, and doing that here would mean inventing a
    /// web address for a note that has none — a link to nothing, and a network request made on behalf
    /// of a local note. The title and the icon are the parts that are true.
    static func metadata(for payload: NoteSharePayload) -> LPLinkMetadata {
        let metadata = LPLinkMetadata()
        metadata.title = payload.sheetTitle
        if let icon = UIImage(named: "AppIcon") ?? Bundle.main.icon {
            metadata.iconProvider = NSItemProvider(object: icon)
        }
        return metadata
    }

    /// The configuration the sheet is built from — the item, plus what names it.
    static func configuration(for payload: NoteSharePayload) -> UIActivityItemsConfiguration {
        let configuration = UIActivityItemsConfiguration(itemProviders: [provider(for: payload)])
        let metadata = metadata(for: payload)
        let title = payload.sheetTitle
        configuration.metadataProvider = { key in
            switch key {
            case .linkPresentationMetadata: return metadata
            case .title: return title
            default: return nil
            }
        }
        return configuration
    }
}

/// Presents the system share sheet for one note.
///
/// A `UIViewControllerRepresentable` rather than SwiftUI's `ShareLink`, because `ShareLink` takes
/// *one* transferable value and this note is deliberately two representations negotiated by the
/// destination.
struct NoteShareSheet: UIViewControllerRepresentable {
    let payload: NoteSharePayload
    /// Called when the sheet closes, however it closed. Cancelling is not a failure and changes
    /// nothing about the note — there is nothing to roll back, because sharing never wrote anything.
    var onFinish: () -> Void = {}

    func makeUIViewController(context: Context) -> UIActivityViewController {
        let controller = UIActivityViewController(
            activityItemsConfiguration: NoteShareItems.configuration(for: payload))
        controller.completionWithItemsHandler = { _, _, _, _ in onFinish() }
        return controller
    }

    func updateUIViewController(_ controller: UIActivityViewController, context: Context) {}
}

private extension Bundle {
    /// The app icon as the sheet's header should show it. `UIImage(named: "AppIcon")` misses it in
    /// some build configurations, so the Info.plist's own record is read as the fallback.
    var icon: UIImage? {
        guard let icons = object(forInfoDictionaryKey: "CFBundleIcons") as? [String: Any],
              let primary = icons["CFBundlePrimaryIcon"] as? [String: Any],
              let files = primary["CFBundleIconFiles"] as? [String],
              let name = files.last
        else { return nil }
        return UIImage(named: name)
    }
}

import SwiftUI

/// The writing toolbar: one floating island above the keyboard holding everything a writer does to a
/// note — its structure and its voice — where their hands already are.
///
/// **This replaces the anti-ribbon rule, and did not sneak past it** (RULES.md §1 and §7, amended
/// 2026-08-20). The rule it replaces said a keyboard-accessory row of style buttons *was* the
/// forbidden formatting bar. The reason it changed is the same reason the Style control shipped in the
/// first place: the capability existed and people could not find it. `Aa` in the navigation bar put the
/// commonest act in the app — making a list — three steps away, at the far end of the screen from the
/// hands. One tap on `•` is not more formatting; it is the formatting we already had, said out loud.
///
/// What has *not* changed is the vocabulary. Six structures, the same six `BlockStyle` offers, routed
/// through the same `DocumentAction.setBlockKind` primitive that typing a marker and speaking a command
/// already use. Bold, italic, colors, and alignment remain excluded — they are inline rich text, a
/// different category, and no amount of room on this bar admits them (RULES.md §7).
struct WritingToolbar: View {

    /// What the bar is showing, which is entirely a question of where the caret is.
    enum Mode: Equatable {
        /// The title has the keyboard. Structure does not apply to a title and voice does not write
        /// into one, so the bar is not there to be misread.
        case hidden
        /// Reading. The note is the whole screen; speaking is the one thing still on offer.
        case voiceOnly
        /// The body has the caret.
        case writing

        static func resolve(bodyFocused: Bool, titleFocused: Bool) -> Mode {
            if titleFocused { return .hidden }
            return bodyFocused ? .writing : .voiceOnly
        }
    }

    var mode: Mode
    /// The style of the block the caret sits in, or `nil` when the selection spans more than one — in
    /// which case nothing is shown as selected, because the selection is not any one style.
    var current: BlockStyle?
    var appendsToEnd: Bool
    var onStyle: (BlockStyle) -> Void
    var onWritingHelp: () -> Void
    var onVoice: () -> Void

    /// The three structures that earn a button of their own: the ones people reach for constantly and
    /// used to have to go hunting for. Heading and Subheading stay inside `Aa` — they are chosen once
    /// per section, not once per line, and this is still As Told rather than a word processor.
    private static let shortcuts: [(BlockStyle, String)] = [
        (.bullet, "list.bullet"), (.numbered, "list.number"), (.checklist, "checklist")
    ]

    var body: some View {
        if mode != .hidden {
            HStack(spacing: DSSpacing.s1) {
                if mode == .writing {
                    styleMenu
                    ForEach(Self.shortcuts, id: \.0) { style, symbol in
                        shortcut(style, symbol: symbol)
                    }
                    Divider().frame(height: 22).padding(.horizontal, DSSpacing.s1)
                }
                voice
            }
            .padding(.horizontal, DSSpacing.s3)
            .padding(.vertical, DSSpacing.s1)
            .background(.thinMaterial, in: Capsule())
            .transition(.opacity.combined(with: .scale(scale: 0.96, anchor: .bottom)))
        }
    }

    // MARK: Controls

    /// A menu rather than a sheet, and that is still a behavioral requirement: a sheet resigns first
    /// responder, so the keyboard would drop and the selection being styled would have to be put back.
    private var styleMenu: some View {
        Menu {
            Picker("Style", selection: styleBinding) {
                ForEach([BlockStyle.paragraph, .heading, .subheading]) { style in
                    Text(style.name).tag(Optional(style))
                }
            }
            .pickerStyle(.inline)
            Divider()
            // Reference material one tap deeper, where losing the keyboard to a sheet costs nothing
            // because nothing is being applied.
            Button("Writing help…") { onWritingHelp() }
        } label: {
            icon("textformat", selected: current == .heading || current == .subheading)
        }
        .accessibilityLabel("Style")
    }

    private func shortcut(_ style: BlockStyle, symbol: String) -> some View {
        Button { onStyle(style) } label: {
            icon(symbol, selected: current == style)
        }
        .accessibilityLabel(style.name)
        .accessibilityAddTraits(current == style ? [.isSelected] : [])
    }

    /// The microphone keeps the clearest accent on the bar. Voice is not a feature bolted to the side
    /// of the editor — it is the other way to write the same note — and it reads as one control among
    /// the writing controls now rather than a lone island in the corner.
    private var voice: some View {
        Button { onVoice() } label: {
            Image(systemName: "mic.fill")
                .font(.system(size: 16, weight: .semibold))
                .foregroundStyle(Color.ds.accent)
                .frame(width: 44, height: 44)
        }
        .accessibilityLabel("Start recording")
        .accessibilityHint(appendsToEnd
            ? "Adds what you say to the end of this note"
            : "Adds what you say at the cursor")
    }

    private func icon(_ symbol: String, selected: Bool) -> some View {
        Image(systemName: symbol)
            .font(.system(size: 16, weight: .medium))
            .foregroundStyle(selected ? Color.ds.accent : Color.ds.textPrimary)
            // The tap target stays 44 points whatever the glyph does inside it.
            .frame(width: 44, height: 44)
            .background {
                if selected {
                    RoundedRectangle(cornerRadius: DSRadius.medium, style: .continuous)
                        .fill(Color.ds.accent.opacity(0.14))
                        .padding(DSSpacing.s1)
                }
            }
            .contentShape(Rectangle())
    }

    /// The menu's selection, refusing a no-op: re-applying the style a line already has would still be
    /// a text edit, and would still cost the writer an undo step.
    private var styleBinding: Binding<BlockStyle?> {
        Binding(
            get: { current },
            set: { chosen in
                guard let chosen, chosen != current else { return }
                onStyle(chosen)
            }
        )
    }
}

import SwiftUI

/// The writing reference, reached from the Style menu's "Writing help…" row — and deliberately with
/// **no actions**: nothing here applies a heading or ticks a box.
///
/// Ordered behavior-first (2026-08-19): what each structure is, how to reach it by tapping or saying
/// it, and what Return does inside it — then speech, then typed markers last, under the honest name
/// "Keyboard shortcuts". It opened with the marker table until the Style menu shipped, which put
/// syntax in front of a reader who now never has to learn any.
///
/// It reached the editor as a standalone `?` until 2026-08-19, when the Style menu absorbed it: two
/// pieces of contextual chrome where the design allows one, and the menu is the surface people
/// actually go to when they want structure. Being a sheet is fine *here* precisely because it applies
/// nothing — losing the keyboard costs a reader nothing, while it would have cost the Style menu the
/// selection it acts on.
///
/// The no-actions rule is what keeps this surface allowed at all. RULES.md §1 forbids a visible
/// formatting toolbar and §7 requires structure affordances to be contextual. A sheet that *tells* you
/// the syntax stays on the right side of that line; a sheet with a row of buttons that applied it
/// would be the ribbon, one tap deeper. Applying belongs to `BlockStyle` and the Style menu, and there
/// must not be a second path to it from here.
struct WritingHelpSheet: View {
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: DSSpacing.s6) {
                    // What the structures *do* comes first. A writer who reads only this section can
                    // make every structure the app has, by tapping, and knows how to get out again —
                    // which is more than the old opening table of markers ever taught.
                    section("Shape your note") {
                        VStack(alignment: .leading, spacing: DSSpacing.s4) {
                            ForEach(WritingHelp.structures) { structure in
                                structureRow(structure)
                            }
                        }
                    }
                    section("Leaving a list") {
                        Text(WritingHelp.leavingAList)
                            .font(.ds.editorBody)
                            .foregroundStyle(Color.ds.textPrimary)
                            .fixedSize(horizontal: false, vertical: true)
                    }
                    // Examples first: a whole utterance shows how the commands sit inside speech,
                    // which the bare vocabulary underneath cannot.
                    section("Say") {
                        VStack(alignment: .leading, spacing: DSSpacing.s4) {
                            ForEach(WritingHelp.voiceExamples) { example in
                                VStack(alignment: .leading, spacing: DSSpacing.s1) {
                                    Text(example.task)
                                        .font(.ds.caption)
                                        .foregroundStyle(Color.ds.textSecondary)
                                    Text("“\(example.utterance)”")
                                        .font(.ds.preview)
                                        .foregroundStyle(Color.ds.textPrimary)
                                        .fixedSize(horizontal: false, vertical: true)
                                }
                                .frame(maxWidth: .infinity, alignment: .leading)
                            }
                        }
                    }
                    section("Every command") {
                        ForEach(WritingHelp.voiceCommands, id: \.self) { command in
                            row(leading: "“\(command)”", trailing: nil, isCode: false)
                        }
                    }
                    // Last, and named as a shortcut rather than as the syntax: nothing above needed it.
                    section("Keyboard shortcuts") {
                        ForEach(WritingHelp.typingMarkers) { marker in
                            row(leading: marker.marker, trailing: marker.name, isCode: true)
                        }
                    }
                    Text(WritingHelp.structurePromise)
                        .font(.ds.caption)
                        .foregroundStyle(Color.ds.textSecondary)
                        .fixedSize(horizontal: false, vertical: true)
                        .padding(.top, DSSpacing.s2)
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(.horizontal, DSSpacing.screenH)
                .padding(.vertical, DSSpacing.s5)
            }
            .background(Color.ds.canvas)
            .navigationTitle("Writing in As Told")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button("Done") { dismiss() }
                        .fontWeight(.semibold)
                        .foregroundStyle(Color.ds.accent)
                }
            }
        }
    }

    /// One structure: its name, the two ways to ask for it, and what Return does inside it.
    @ViewBuilder
    private func structureRow(_ structure: WritingHelp.Structure) -> some View {
        VStack(alignment: .leading, spacing: DSSpacing.s1) {
            Text(structure.name)
                .font(.ds.editorBody)
                .foregroundStyle(Color.ds.textPrimary)
            Text("\(structure.tapPath), or say “\(structure.spoken).”")
                .font(.ds.caption)
                .foregroundStyle(Color.ds.textSecondary)
                .fixedSize(horizontal: false, vertical: true)
            if let behavior = structure.behavior {
                Text(behavior)
                    .font(.ds.caption)
                    .foregroundStyle(Color.ds.textSecondary)
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        // Read as one description, not four unrelated fragments.
        .accessibilityElement(children: .combine)
    }

    @ViewBuilder
    private func section(_ title: String, @ViewBuilder content: () -> some View) -> some View {
        VStack(alignment: .leading, spacing: DSSpacing.s3) {
            Text(title.uppercased())
                .font(.ds.dateLabel)
                .foregroundStyle(Color.ds.textTertiary)
                .accessibilityAddTraits(.isHeader)
            VStack(alignment: .leading, spacing: DSSpacing.s3) { content() }
        }
    }

    /// One reference line. The marker is monospaced because the trailing space is load-bearing —
    /// "- " is a bullet and "-" is a hyphen — and a proportional font hides exactly that difference.
    @ViewBuilder
    private func row(leading: String, trailing: String?, isCode: Bool) -> some View {
        // Stacks at larger text sizes rather than crushing either column (docs/03-design-system.md
        // accessibility: every screen must survive the largest Dynamic Type setting).
        ViewThatFits(in: .horizontal) {
            HStack(alignment: .firstTextBaseline, spacing: DSSpacing.s4) {
                markerText(leading, isCode: isCode)
                if let trailing {
                    Text(trailing)
                        .font(.ds.editorBody)
                        .foregroundStyle(Color.ds.textPrimary)
                }
                Spacer(minLength: 0)
            }
            VStack(alignment: .leading, spacing: DSSpacing.s1) {
                markerText(leading, isCode: isCode)
                if let trailing {
                    Text(trailing)
                        .font(.ds.editorBody)
                        .foregroundStyle(Color.ds.textPrimary)
                }
            }
        }
        // Read as one phrase — "hyphen space, Bulleted List" — instead of two unrelated fragments.
        .accessibilityElement(children: .combine)
    }

    @ViewBuilder
    private func markerText(_ text: String, isCode: Bool) -> some View {
        if isCode {
            Text(text)
                .font(.system(.body, design: .monospaced))
                .foregroundStyle(Color.ds.accent)
                .padding(.horizontal, DSSpacing.s2)
                .padding(.vertical, DSSpacing.s1)
                .background(Color.ds.surface, in: RoundedRectangle(cornerRadius: DSRadius.small))
                // VoiceOver reads "- [ ] " as punctuation soup; name the marker instead.
                .accessibilityLabel(Self.spokenMarker(text))
        } else {
            Text(text)
                .font(.ds.editorBody)
                .foregroundStyle(Color.ds.textPrimary)
        }
    }

    /// A marker said aloud. Trailing space is dropped — it matters to the parser, not to a listener,
    /// who cannot hear it anyway and would only be told "space" for no benefit.
    static func spokenMarker(_ marker: String) -> String {
        switch marker.trimmingCharacters(in: .whitespaces) {
        case "#": return "Number sign"
        case "##": return "Two number signs"
        case "-": return "Hyphen"
        case "1.": return "One, period"
        case "- [ ]": return "Hyphen, open bracket, space, close bracket"
        default: return marker
        }
    }
}

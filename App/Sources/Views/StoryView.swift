import SwiftUI
import HeroDomain
import HeroContent

/// Dialogue player for a content `StoryChapter` (doc 25). The speaker's portrait stands on the
/// backdrop; lines appear one per tap in full-width bubbles with large type so they read at a
/// glance (owner: "stupid simple to read, like Pokémon or Fire Emblem"). Hero bubbles sit on the
/// left under the right-hand portrait and the guide's on the right, as in the owner's boards.
struct StoryView: View {
    @Environment(AppState.self) private var state
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    let chapter: ContentBundle.StoryChapter
    /// Draft recipe while onboarding (hero portrait becomes the live sprite once it exists).
    var heroRecipe: AvatarRecipe?
    let onFinish: () -> Void

    @State private var beatIndex = 0
    @State private var lineCount = 1          // lines of the current beat revealed so far
    @State private var token = 0              // bumps per reveal for the bubble transition

    private var beat: ContentBundle.StoryBeat { chapter.beats[min(beatIndex, chapter.beats.count - 1)] }
    private var speaker: ContentBundle.Character? { state.bundle.character(beat.speaker) }
    private var isLastLine: Bool { beatIndex >= chapter.beats.count - 1 && lineCount >= beat.lines.count }
    private var heroOnRight: Bool { speaker?.side != "left" }

    var body: some View {
        VStack(spacing: 0) {
            stage
            ScrollViewReader { proxy in
                ScrollView {
                    VStack(alignment: heroOnRight ? .leading : .trailing, spacing: NeoTokyo.Spacing.sm) {
                        ForEach(Array(beat.lines.prefix(lineCount).enumerated()), id: \.offset) { pair in
                            Bubble(text: pair.element.resolved(worldName: state.bundle.worldName), trailing: !heroOnRight)
                                .id(pair.offset)
                                .transition(reduceMotion ? .opacity : .move(edge: .bottom).combined(with: .opacity))
                        }
                    }
                    .frame(maxWidth: .infinity, alignment: heroOnRight ? .leading : .trailing)
                    .padding(.horizontal, NeoTokyo.Spacing.lg)
                    .padding(.top, NeoTokyo.Spacing.md)
                }
                .onChange(of: token) { _, _ in withAnimation { proxy.scrollTo(lineCount - 1, anchor: .bottom) } }
            }
            footer
        }
        .background(NeoTokyo.Surface.base.ignoresSafeArea())
        .contentShape(Rectangle())
        .onTapGesture { advance() }
        .animation(.easeOut(duration: 0.22), value: token)
    }

    /// `BackdropImage` resolves by asset set id (typed as a backdrop id for historical reasons).
    private var stageBackdrop: BackdropID {
        BackdropID(state.bundle.backdrop(chapter.backdropID)?.assetSetID.rawValue ?? "backdrop.alley_awakening")
    }

    /// Backdrop with the speaker's portrait low on one side, bleeding off the top like Home.
    private var stage: some View {
        ZStack(alignment: heroOnRight ? .bottomTrailing : .bottomLeading) {
            BackdropImage(assetSetID: stageBackdrop)
            if let speaker {
                SpeakerPortrait(character: speaker, recipe: heroRecipe, size: 170)
                    .padding(.horizontal, NeoTokyo.Spacing.md)
                    .id(speaker.id)
                    .transition(.opacity)
            }
        }
        .frame(height: 320)
        .ignoresSafeArea(edges: .top)
        .mask(LinearGradient(stops: [.init(color: .black, location: 0), .init(color: .black, location: 0.88), .init(color: .clear, location: 1)], startPoint: .top, endPoint: .bottom))
    }

    private var footer: some View {
        HStack {
            if !isLastLine {
                Text("Tap to continue").font(HeroFont.caption).foregroundStyle(NeoTokyo.Text.muted)
                Spacer()
            } else {
                Button(chapter.then == "home" ? "Begin" : "Continue") { onFinish() }
                    .buttonStyle(PrimaryButtonStyle())
            }
        }
        .padding(.horizontal, NeoTokyo.Spacing.lg)
        .padding(.vertical, NeoTokyo.Spacing.md)
    }

    private func advance() {
        if lineCount < beat.lines.count { lineCount += 1; token += 1; return }
        if beatIndex < chapter.beats.count - 1 { beatIndex += 1; lineCount = 1; token += 1; return }
        onFinish()
    }
}

/// Full-width dialogue bubble: large type, generous padding, glass with no stroke (doc 19).
/// Supports Markdown emphasis from content (`**soul bound**`, `*escape*`).
struct Bubble: View {
    let text: String
    var trailing = false
    var body: some View {
        Text(.init(text))
            .font(HeroFont.dialogue)
            .foregroundStyle(NeoTokyo.Text.primary)
            .multilineTextAlignment(.leading)
            .fixedSize(horizontal: false, vertical: true)
            .padding(.horizontal, NeoTokyo.Spacing.lg)
            .padding(.vertical, NeoTokyo.Spacing.md)
            .frame(maxWidth: .infinity, alignment: .leading)
            .glass(cornerRadius: NeoTokyo.Radius.lg, tint: NeoTokyo.Surface.overlay)
            .padding(trailing ? .leading : .trailing, NeoTokyo.Spacing.xl)
    }
}

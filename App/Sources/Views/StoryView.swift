import SwiftUI
import HeroDomain
import HeroContent

/// Dialogue player for a content `StoryChapter` (doc 25). The speaker's portrait stands on the
/// backdrop; lines appear one per tap in full-width bubbles with large type so they read at a
/// glance (owner: "stupid simple to read, like Pokémon or Fire Emblem"). Which side a speaker stands on is
/// content (`characters[].side`): the hero is always on the left (owner, 2026-10-16), everyone else on the
/// right. Owner brief 2026-10-16 (P2-9): the bubble sits on the speaker's side under their name, the portrait is
/// larger and framed, speakers cross-fade, and the tap affordance pulses.
struct StoryView: View {
    @Environment(AppState.self) private var state
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    let chapter: ContentBundle.StoryChapter
    /// Draft recipe while onboarding (hero portrait becomes the live sprite once it exists).
    var heroRecipe: AvatarRecipe?
    /// Doc 40 #8: what this scene opens ("New area · Colossus Gym"), shown over the stage for the first beats.
    var banner: String? = nil
    let onFinish: () -> Void
    @State private var bannerShown = true

    @State private var beatIndex = 0
    @State private var lineCount = 1          // lines of the current beat revealed so far
    @State private var token = 0              // bumps per reveal for the bubble transition

    private var beat: ContentBundle.StoryBeat { chapter.beats[min(beatIndex, chapter.beats.count - 1)] }
    private var speaker: ContentBundle.Character? { state.bundle.character(beat.speaker) }
    private var isLastLine: Bool { beatIndex >= chapter.beats.count - 1 && lineCount >= beat.lines.count }
    private var speakerOnRight: Bool { speaker?.side != "left" }
    /// The last two revealed lines of the current beat, keyed by their index so transitions track identity.
    private var visibleLines: [(offset: Int, line: ContentBundle.StoryLine)] {
        let revealed = Array(beat.lines.prefix(lineCount).enumerated()).map { (offset: $0.offset, line: $0.element) }
        return Array(revealed.suffix(2))
    }

    var body: some View {
        VStack(spacing: 0) {
            stage
            // Owner rule (2026-10-02): at most two bubbles on screen, no scrolling. The newest enters
            // from below; the one before it stays; anything older slides up and fades out.
            VStack(alignment: speakerOnRight ? .trailing : .leading, spacing: NeoTokyo.Spacing.sm) {
                if let speaker {
                    Text(speaker.id == "hero" ? (heroRecipe?.name ?? state.recipe?.name ?? speaker.displayName) : speaker.displayName)
                        .font(HeroFont.captionMedium).foregroundStyle(NeoTokyo.Hierarchy.primary)
                        .padding(.horizontal, NeoTokyo.Spacing.sm)
                        .id("name.\(speaker.id.rawValue)").transition(.opacity)
                }
                ForEach(Array(visibleLines.enumerated()), id: \.element.offset) { pair in
                    Bubble(text: pair.element.line.resolved(worldName: state.bundle.worldName), trailing: speakerOnRight)
                        .opacity(pair.offset == 0 && visibleLines.count == 2 ? 0.55 : 1)
                        .transition(reduceMotion ? .opacity : .asymmetric(insertion: .move(edge: .bottom).combined(with: .opacity), removal: .move(edge: .top).combined(with: .opacity)))
                }
            }
            .frame(maxWidth: .infinity, alignment: speakerOnRight ? .trailing : .leading)
            .padding(.horizontal, NeoTokyo.Spacing.lg)
            .padding(.top, NeoTokyo.Spacing.md)
            .frame(maxHeight: .infinity, alignment: .top)
            .clipped()
            footer
        }
        .background(NeoTokyo.Surface.base.ignoresSafeArea())
        .contentShape(Rectangle())
        .onTapGesture { advance() }
        .animation(.easeOut(duration: 0.22), value: token)
        .animation(.easeOut(duration: 0.3), value: beat.speaker)
    }

    /// `BackdropImage` resolves by asset set id (typed as a backdrop id for historical reasons).
    private var stageBackdrop: BackdropID {
        BackdropID(state.bundle.backdrop(chapter.backdropID)?.assetSetID.rawValue ?? "backdrop.alley_awakening")
    }

    /// Backdrop with the speaker's portrait low on one side, bleeding off the top like Home.
    private var stage: some View {
        ZStack(alignment: speakerOnRight ? .bottomTrailing : .bottomLeading) {
            BackdropImage(assetSetID: stageBackdrop)
            if let speaker {
                SpeakerPortrait(character: speaker, recipe: heroRecipe, size: 160, facingLeft: speakerOnRight)   // owner QA 2026-10-17: 200 was too big
                    .padding(NeoTokyo.Spacing.xs)
                    .background(NeoTokyo.Surface.scrim.opacity(0.35), in: RoundedRectangle(cornerRadius: NeoTokyo.Radius.lg, style: .continuous))
                    .padding(.horizontal, NeoTokyo.Spacing.md)
                    .id(speaker.id)
                    .transition(.opacity.combined(with: .scale(scale: 0.97)))
            }
        }
        .frame(height: 320)
        .overlay(alignment: .bottom) {
            // Owner QA 2026-10-18: at the top it was cut off; it sits under the graphic now, centred, gold (progression).
            if let banner, bannerShown {
                HStack(spacing: 8) {
                    Image(systemName: "sparkles").font(HeroFont.captionMedium)
                    Text(banner).font(HeroFont.headline)
                }
                .foregroundStyle(NeoTokyo.Hierarchy.primary)
                .padding(.horizontal, NeoTokyo.Spacing.lg).padding(.vertical, NeoTokyo.Spacing.sm)
                .glass(cornerRadius: NeoTokyo.Radius.md, tint: NeoTokyo.Surface.scrim)
                .overlay(RoundedRectangle(cornerRadius: NeoTokyo.Radius.md, style: .continuous).stroke(NeoTokyo.Hierarchy.primary.opacity(0.5), lineWidth: 1))
                .shadow(color: NeoTokyo.Hierarchy.primary.opacity(0.3), radius: 14)
                .padding(.bottom, 6)
                .transition(.scale(scale: 0.9).combined(with: .opacity))
                .task { try? await Task.sleep(for: .milliseconds(3500)); withAnimation(.easeIn(duration: 0.3)) { bannerShown = false } }
            }
        }
        .ignoresSafeArea(edges: .top)
        .mask(LinearGradient(stops: [.init(color: .black, location: 0), .init(color: .black, location: 0.88), .init(color: .clear, location: 1)], startPoint: .top, endPoint: .bottom))
    }

    private var footer: some View {
        HStack {
            if !isLastLine {
                TapAffordance()
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

/// "Tap to continue", pulsing with a chevron (owner brief 2026-10-16, P2-9). Still under Reduce Motion.
struct TapAffordance: View {
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var on = false
    var body: some View {
        HStack(spacing: 6) {
            Text("Tap to continue").font(HeroFont.captionMedium)
            Image(systemName: "chevron.down").font(HeroFont.label).offset(y: on ? 2 : 0)
        }
        .foregroundStyle(NeoTokyo.Text.secondary.opacity(on ? 1 : 0.55))
        .onAppear { guard !reduceMotion else { on = true; return }; withAnimation(.easeInOut(duration: 0.9).repeatForever(autoreverses: true)) { on = true } }
    }
}

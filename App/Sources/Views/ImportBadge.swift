import SwiftUI
import HeroDomain

/// Small provenance badge for imported activity: verified (blue), counted in a workout, or history only.
struct ImportBadge: View {
    let disposition: ImportDisposition?
    var body: some View {
        if let disposition {
            let (label, color): (String, Color) = {
                switch disposition {
                case .imported, .duplicate: return ("Health", NeoTokyo.Hierarchy.fallback)
                case .historyOnlyOverlap: return ("In workout", NeoTokyo.Text.muted)
                case .historyOnlyUnmapped: return ("History", NeoTokyo.Text.muted)
                }
            }()
            Text(label)
                .font(HeroFont.label).tracking(0.6).textCase(.uppercase)
                .foregroundStyle(color)
                .padding(.horizontal, 6).padding(.vertical, 2)
                .background(color.opacity(0.14), in: Capsule())
        }
    }
}

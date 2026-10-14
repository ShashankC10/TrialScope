import SwiftUI
import TrialCore

enum Palette {
    static let teal = Color(red: 0.08, green: 0.40, blue: 0.38)
    static let ink = Color("AccentInk", bundle: .module)
    static let mint = Color(red: 0.78, green: 0.91, blue: 0.85)
    static let coral = Color(red: 0.96, green: 0.65, blue: 0.44)
    static let amber = Color(red: 0.62, green: 0.38, blue: 0.05)
}

struct Canvas: ViewModifier {
    @Environment(\.colorScheme) private var scheme
    func body(content: Content) -> some View {
        content.background(scheme == .dark ? Color(red: 0.07, green: 0.10, blue: 0.10) : Color(red: 0.96, green: 0.97, blue: 0.95))
    }
}

extension View {
    func canvas() -> some View { modifier(Canvas()) }
    func readableWidth() -> some View { frame(maxWidth: 760).frame(maxWidth: .infinity) }
    @ViewBuilder func inlineTitle() -> some View {
        #if os(iOS)
        navigationBarTitleDisplayMode(.inline)
        #else
        self
        #endif
    }
    /// The standard rounded surface used by cards and grouped content.
    func surface(radius: CGFloat = 20) -> some View {
        background(.background, in: RoundedRectangle(cornerRadius: radius))
            .overlay(RoundedRectangle(cornerRadius: radius).strokeBorder(.primary.opacity(0.06)))
    }
}

// MARK: - Layout

/// Left-to-right layout that wraps onto new lines, so pills never truncate at large text sizes.
struct FlowLayout: Layout {
    var spacing: CGFloat = 8

    func sizeThatFits(proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) -> CGSize {
        arrange(in: proposal.width ?? .infinity, subviews: subviews).size
    }

    func placeSubviews(in bounds: CGRect, proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) {
        let result = arrange(in: bounds.width, subviews: subviews)
        for (index, origin) in result.origins.enumerated() {
            subviews[index].place(at: CGPoint(x: bounds.minX + origin.x, y: bounds.minY + origin.y), proposal: .unspecified)
        }
    }

    private func arrange(in width: CGFloat, subviews: Subviews) -> (size: CGSize, origins: [CGPoint]) {
        var origins: [CGPoint] = []
        var x: CGFloat = 0, y: CGFloat = 0, rowHeight: CGFloat = 0, maxX: CGFloat = 0
        for subview in subviews {
            let size = subview.sizeThatFits(.unspecified)
            if x > 0, x + size.width > width { x = 0; y += rowHeight + spacing; rowHeight = 0 }
            origins.append(CGPoint(x: x, y: y))
            x += size.width + spacing
            rowHeight = max(rowHeight, size.height)
            maxX = max(maxX, x - spacing)
        }
        return (CGSize(width: maxX, height: y + rowHeight), origins)
    }
}

// MARK: - Pills

struct Pill: View {
    let text: String
    var icon: String?
    var foreground: Color = .secondary
    var background: Color = Color.secondary.opacity(0.12)
    var body: some View {
        HStack(spacing: 5) {
            if let icon { Image(systemName: icon).font(.caption2.weight(.bold)).accessibilityHidden(true) }
            Text(text).lineLimit(1)
        }
        .font(.caption.weight(.semibold))
        .foregroundStyle(foreground)
        .padding(.horizontal, 10).padding(.vertical, 6)
        .background(background, in: Capsule())
    }
}

struct StatusPill: View {
    let status: RecruitmentStatus
    var text: String? = nil
    var body: some View {
        Pill(text: text ?? status.rawValue, icon: icon, foreground: foreground, background: background)
    }
    private var icon: String {
        switch status {
        case .recruiting: "circle.fill"
        case .notYetRecruiting: "clock"
        case .active: "pause.circle"
        case .unknown: "questionmark.circle"
        }
    }
    private var foreground: Color {
        switch status {
        case .recruiting: Palette.teal
        case .notYetRecruiting: Palette.amber
        case .active, .unknown: .secondary
        }
    }
    private var background: Color {
        switch status {
        case .recruiting: Palette.mint
        case .notYetRecruiting: Palette.coral.opacity(0.25)
        case .active, .unknown: Color.secondary.opacity(0.12)
        }
    }
}

struct PhasePill: View {
    let trial: Trial
    var body: some View {
        if trial.phase != .unknown || trial.apiPhase != nil, trial.phaseDescription != "Not provided" {
            Pill(text: Self.display(trial.phaseDescription), icon: "chart.bar.xaxis")
        }
    }
    /// Registry enums such as "PHASE2" or "PHASE1/PHASE2" read better as "Phase 2" / "Phase 1/2".
    static func display(_ raw: String) -> String {
        let upper = raw.uppercased()
        guard upper.hasPrefix("PHASE") else { return raw }
        let numbers = upper.split(separator: "/").map {
            $0.replacingOccurrences(of: "PHASE", with: "").trimmingCharacters(in: .whitespaces)
        }
        return "Phase " + numbers.joined(separator: "/")
    }
}

// MARK: - Cards

struct TrialCard: View {
    let trial: Trial
    var saved = false
    var note: String? = nil
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(alignment: .firstTextBaseline, spacing: 6) {
                Text(trial.primaryCondition).font(.caption.weight(.semibold)).foregroundStyle(Palette.ink).lineLimit(1)
                if trial.additionalConditionCount > 0 {
                    Text("+\(trial.additionalConditionCount)").font(.caption).foregroundStyle(.secondary)
                }
                Spacer(minLength: 8)
                if saved { Image(systemName: "bookmark.fill").foregroundStyle(Palette.ink).accessibilityLabel("Saved") }
            }
            Text(trial.title)
                .font(.system(.title3, design: .serif, weight: .semibold))
                .foregroundStyle(.primary).multilineTextAlignment(.leading)
                .lineLimit(3).fixedSize(horizontal: false, vertical: true)
            if trial.hasSummary {
                Text(trial.summary).font(.subheadline).foregroundStyle(.secondary).lineLimit(2).multilineTextAlignment(.leading)
            }
            FlowLayout(spacing: 8) {
                StatusPill(status: trial.status, text: trial.statusDescription)
                PhasePill(trial: trial)
            }
            VStack(alignment: .leading, spacing: 6) {
                Label {
                    Text(trial.location) + Text(trial.additionalSiteCount > 0 ? "  +\(trial.additionalSiteCount) more" : "").foregroundStyle(.tertiary)
                } icon: { Image(systemName: "mappin.and.ellipse") }
                Label(trial.ageDescription, systemImage: "person")
            }
            .font(.caption).foregroundStyle(.secondary).lineLimit(1)
            if let note, !note.isEmpty {
                Label(note, systemImage: "note.text").font(.caption).foregroundStyle(Palette.ink).lineLimit(2)
                    .padding(10).frame(maxWidth: .infinity, alignment: .leading)
                    .background(Palette.mint.opacity(0.35), in: RoundedRectangle(cornerRadius: 10))
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(18)
        .surface(radius: 20)
        .contentShape(RoundedRectangle(cornerRadius: 20))
        .accessibilityElement(children: .combine)
    }
}

struct TrialCardSkeleton: View {
    @State private var dim = false
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            bar(width: 90, height: 10)
            bar(width: nil, height: 18)
            bar(width: 220, height: 18)
            bar(width: nil, height: 12)
            HStack { bar(width: 90, height: 26, capsule: true); bar(width: 70, height: 26, capsule: true) }
            bar(width: 160, height: 10)
        }
        .padding(18).frame(maxWidth: .infinity, alignment: .leading).surface(radius: 20)
        .opacity(dim ? 0.55 : 1)
        .animation(.easeInOut(duration: 0.9).repeatForever(autoreverses: true), value: dim)
        .onAppear { dim = true }
        .accessibilityHidden(true)
    }
    private func bar(width: CGFloat?, height: CGFloat, capsule: Bool = false) -> some View {
        RoundedRectangle(cornerRadius: capsule ? height / 2 : 5)
            .fill(Color.secondary.opacity(0.18))
            .frame(width: width, height: height)
            .frame(maxWidth: width == nil ? .infinity : nil, alignment: .leading)
    }
}

// MARK: - Small shared views

struct DemoNotice: View {
    var body: some View {
        Label("Demo catalog · Fictional studies", systemImage: "flask")
            .font(.caption).foregroundStyle(.secondary)
            .frame(maxWidth: .infinity).padding(.vertical, 12)
    }
}

struct EligibilityNote: View {
    var body: some View {
        Label("A search match isn’t an eligibility determination. A study team reviews the full criteria with you.", systemImage: "info.circle")
            .font(.footnote).foregroundStyle(.secondary)
            .frame(maxWidth: .infinity, alignment: .leading)
    }
}

struct SectionTitle: View {
    let title: String
    var subtitle: String? = nil
    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(title).font(.title2.weight(.bold))
            if let subtitle { Text(subtitle).font(.subheadline).foregroundStyle(.secondary) }
        }.frame(maxWidth: .infinity, alignment: .leading)
    }
}

/// A selectable filter chip used above the results.
struct FilterChip: View {
    let title: String
    var icon: String?
    var isOn = false
    var body: some View {
        HStack(spacing: 6) {
            if let icon { Image(systemName: icon).font(.caption.weight(.semibold)) }
            Text(title).font(.subheadline.weight(.medium))
        }
        .padding(.horizontal, 14).padding(.vertical, 9)
        .foregroundStyle(isOn ? Color.white : Palette.ink)
        .background(isOn ? Palette.teal : Palette.teal.opacity(0.08), in: Capsule())
        .contentShape(Capsule())
    }
}

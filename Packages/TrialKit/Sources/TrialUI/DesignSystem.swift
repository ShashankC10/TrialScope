import SwiftUI
import TrialCore

enum Palette {
    static let teal = Color(red: 0.08, green: 0.40, blue: 0.38)
    static let ink = Color("AccentInk", bundle: .module)
    static let mint = Color(red: 0.78, green: 0.91, blue: 0.85)
    static let coral = Color(red: 0.96, green: 0.65, blue: 0.44)
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
}

struct StatusPill: View {
    let status: RecruitmentStatus
    var body: some View {
        Label(status.rawValue, systemImage: status == .recruiting ? "circle.fill" : "clock")
            .font(.caption.weight(.semibold))
            .foregroundStyle(status == .recruiting ? Palette.teal : Color.secondary)
            .padding(.horizontal, 10).padding(.vertical, 7)
            .background(status == .recruiting ? Palette.mint : Color.secondary.opacity(0.1), in: Capsule())
    }
}

struct TrialCard: View {
    let trial: Trial
    var saved = false
    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            HStack(alignment: .top) {
                Text(trial.condition.uppercased()).font(.caption.weight(.bold)).tracking(1.3)
                    .foregroundStyle(Palette.ink)
                Spacer()
                if saved { Image(systemName: "bookmark.fill").foregroundStyle(Palette.ink).accessibilityLabel("Saved") }
            }
            Text(trial.title).font(.title3.weight(.semibold)).foregroundStyle(.primary).fixedSize(horizontal: false, vertical: true)
            Text(trial.summary).font(.subheadline).foregroundStyle(.secondary).lineLimit(3)
            ViewThatFits(in: .horizontal) {
                HStack { StatusPill(status: trial.status); Spacer(); Text(trial.phase.rawValue).font(.caption).foregroundStyle(.secondary) }
                VStack(alignment: .leading, spacing: 8) { StatusPill(status: trial.status); Text(trial.phase.rawValue).font(.caption) }
            }
            Divider()
            HStack {
                Label(trial.location, systemImage: "mappin.and.ellipse")
                Spacer()
                Image(systemName: "arrow.up.right")
            }.font(.caption).foregroundStyle(.secondary)
        }
        .padding(20)
        .background(.background, in: RoundedRectangle(cornerRadius: 22))
        .overlay(RoundedRectangle(cornerRadius: 22).strokeBorder(.primary.opacity(0.06)))
        .contentShape(RoundedRectangle(cornerRadius: 22))
        .accessibilityElement(children: .combine)
    }
}

struct DemoNotice: View {
    var body: some View {
        Label("Demo catalog · Fictional studies", systemImage: "flask")
            .font(.caption).foregroundStyle(.secondary)
            .frame(maxWidth: .infinity).padding(.vertical, 12)
    }
}

struct SectionTitle: View {
    let title: String
    let subtitle: String
    var body: some View {
        VStack(alignment: .leading, spacing: 5) {
            Text(title).font(.title2.weight(.bold))
            Text(subtitle).font(.subheadline).foregroundStyle(.secondary)
        }.frame(maxWidth: .infinity, alignment: .leading)
    }
}

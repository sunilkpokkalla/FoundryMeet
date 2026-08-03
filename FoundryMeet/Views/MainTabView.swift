import SwiftUI

struct MainTabView: View {
    @State private var selectedTab: AppTab = .discover

    var body: some View {
        VStack(spacing: 0) {
            Group {
                switch selectedTab {
                case .discover:
                    DiscoveryView()
                case .hub:
                    NetworkingHubView()
                case .messages:
                    MessagesView(isTabRoot: true)
                case .schedule:
                    SchedulingView()
                case .history:
                    MatchHistoryView()
                }
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)

            MainTabBar(selectedTab: $selectedTab)
        }
        .background(AppColors.surface.ignoresSafeArea())
    }
}

private enum AppTab: Hashable, CaseIterable {
    case discover, hub, messages, schedule, history

    var title: String {
        switch self {
        case .discover: return "Discover"
        case .hub: return "Hub"
        case .messages: return "Messages"
        case .schedule: return "Schedule"
        case .history: return "History"
        }
    }

    var icon: String {
        switch self {
        case .discover: return "sparkle"
        case .hub: return "globe"
        case .messages: return "bubble.left.and.bubble.right"
        case .schedule: return "calendar"
        case .history: return "clock"
        }
    }
}

private struct MainTabBar: View {
    @Binding var selectedTab: AppTab

    var body: some View {
        VStack(spacing: 0) {
            Rectangle()
                .fill(AppColors.hairline)
                .frame(height: 1)

            HStack(spacing: 0) {
                ForEach(AppTab.allCases, id: \.self) { tab in
                    Button {
                        withAnimation(.easeInOut(duration: 0.18)) {
                            selectedTab = tab
                        }
                    } label: {
                        VStack(spacing: 6) {
                            Image(systemName: tab.icon)
                                .font(.system(size: 17, weight: selectedTab == tab ? .semibold : .regular))
                                .symbolRenderingMode(.monochrome)

                            Text(tab.title)
                                .font(.system(size: 9, weight: selectedTab == tab ? .semibold : .medium))
                                .tracking(0.1)
                                .lineLimit(1)
                                .minimumScaleFactor(0.8)

                            Capsule()
                                .fill(selectedTab == tab ? AppColors.onSurface : Color.clear)
                                .frame(width: 14, height: 2)
                        }
                        .foregroundColor(
                            selectedTab == tab
                                ? AppColors.onSurface
                                : AppColors.onSurfaceVariant.opacity(0.45)
                        )
                        .frame(maxWidth: .infinity)
                        .padding(.top, 12)
                        .padding(.bottom, 6)
                        .contentShape(Rectangle())
                    }
                    .buttonStyle(.plain)
                    .accessibilityLabel(tab.title)
                    .accessibilityAddTraits(selectedTab == tab ? [.isSelected] : [])
                }
            }
            .padding(.horizontal, 2)
            .background(AppColors.surfaceContainerLowest)
        }
        .background(AppColors.surfaceContainerLowest.ignoresSafeArea(edges: .bottom))
    }
}

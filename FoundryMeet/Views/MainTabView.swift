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

private enum AppTab: Hashable {
    case discover, hub, schedule, history
}

private struct MainTabBar: View {
    @Binding var selectedTab: AppTab

    private let tabs: [(AppTab, String, String)] = [
        (.discover, "Discover", "sparkles"),
        (.hub, "Hub", "globe"),
        (.schedule, "Schedule", "calendar"),
        (.history, "History", "clock")
    ]

    var body: some View {
        VStack(spacing: 0) {
            Rectangle()
                .fill(Color.black.opacity(0.06))
                .frame(height: 1)

            HStack(spacing: 0) {
                ForEach(tabs, id: \.0) { tab, title, icon in
                    Button {
                        selectedTab = tab
                    } label: {
                        VStack(spacing: 4) {
                            Image(systemName: icon)
                                .font(.system(size: 20, weight: selectedTab == tab ? .semibold : .regular))
                            Text(title)
                                .font(.system(size: 11, weight: selectedTab == tab ? .semibold : .medium))
                        }
                        .foregroundColor(selectedTab == tab ? AppColors.onSurface : AppColors.onSurfaceVariant.opacity(0.55))
                        .frame(maxWidth: .infinity)
                        .padding(.top, 10)
                        .padding(.bottom, 8)
                        .contentShape(Rectangle())
                    }
                    .buttonStyle(.plain)
                    .accessibilityLabel(title)
                    .accessibilityAddTraits(selectedTab == tab ? [.isSelected] : [])
                }
            }
            .padding(.horizontal, 8)
            .padding(.bottom, 2)
            .background(AppColors.surfaceContainerLowest)
        }
        .background(AppColors.surfaceContainerLowest.ignoresSafeArea(edges: .bottom))
    }
}

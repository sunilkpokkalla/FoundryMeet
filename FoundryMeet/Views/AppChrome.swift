import SwiftUI

/// Shared top chrome: centered logo + balanced profile control.
struct AppNavToolbar: ToolbarContent {
    @Binding var showProfile: Bool
    var profileInitials: String = ""

    var body: some ToolbarContent {
        // Matching width on the leading side keeps the logo optically centered.
        ToolbarItem(placement: .topBarLeading) {
            Color.clear
                .frame(width: 36, height: 36)
                .accessibilityHidden(true)
        }

        ToolbarItem(placement: .principal) {
            Image("Logo")
                .resizable()
                .scaledToFit()
                .frame(height: 26)
                .accessibilityLabel("FoundryMeet")
        }

        ToolbarItem(placement: .topBarTrailing) {
            Button {
                showProfile = true
            } label: {
                Group {
                    if profileInitials.isEmpty {
                        Image(systemName: "person")
                            .font(.system(size: 14, weight: .semibold))
                    } else {
                        Text(profileInitials)
                            .font(.system(size: 12, weight: .bold))
                    }
                }
                .foregroundColor(AppColors.onSurface)
                .frame(width: 36, height: 36)
                .background(
                    Circle()
                        .stroke(AppColors.onSurface.opacity(0.12), lineWidth: 1)
                        .background(Circle().fill(AppColors.surfaceContainerLowest))
                )
            }
            .buttonStyle(.plain)
            .accessibilityLabel("Account")
        }
    }
}

extension View {
    func appNavigationChrome(
        showProfile: Binding<Bool>,
        profileInitials: String = ""
    ) -> some View {
        self
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                AppNavToolbar(showProfile: showProfile, profileInitials: profileInitials)
            }
            .toolbarBackground(AppColors.surface, for: .navigationBar)
            .toolbarBackground(.visible, for: .navigationBar)
    }
}

import SwiftUI

struct AppHeader: View {
    @Binding var showProfile: Bool
    var profileInitials: String = ""

    var body: some View {
        ZStack {
            // Brand lockup — truly centered, independent of trailing controls.
            HStack(spacing: 8) {
                Image("Logo")
                    .resizable()
                    .scaledToFit()
                    .frame(width: 20, height: 20)

                Text("FoundryMeet")
                    .font(.system(size: 17, weight: .semibold))
                    .tracking(-0.3)
                    .foregroundColor(AppColors.onSurface)
            }
            .accessibilityElement(children: .combine)
            .accessibilityLabel("FoundryMeet")

            HStack {
                Spacer()
                Button {
                    showProfile = true
                } label: {
                    Group {
                        if profileInitials.isEmpty {
                            Image(systemName: "person")
                                .font(.system(size: 13, weight: .medium))
                        } else {
                            Text(profileInitials.prefix(1).uppercased())
                                .font(.system(size: 13, weight: .semibold))
                        }
                    }
                    .foregroundColor(AppColors.onSurface.opacity(0.85))
                    .frame(width: 34, height: 34)
                    .background(Circle().fill(AppColors.surfaceContainerLowest))
                    .overlay(Circle().stroke(AppColors.hairline, lineWidth: 1))
                }
                .buttonStyle(.plain)
                .accessibilityLabel("Account")
            }
        }
        .padding(.horizontal, 20)
        .padding(.top, 6)
        .padding(.bottom, 12)
        .background(AppColors.surface)
    }
}

extension View {
    func hideSystemNavBar() -> some View {
        self
            .navigationBarTitleDisplayMode(.inline)
            .toolbar(.hidden, for: .navigationBar)
    }
}

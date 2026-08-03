import SwiftUI

struct AppHeader: View {
    @Binding var showProfile: Bool
    var profileInitials: String = ""

    var body: some View {
        HStack {
            Image("Logo")
                .resizable()
                .scaledToFit()
                .frame(width: 28, height: 28)
                .accessibilityLabel("FoundryMeet")

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

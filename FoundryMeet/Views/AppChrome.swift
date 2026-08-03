import SwiftUI
import UIKit

struct AppHeader: View {
    @Binding var showProfile: Bool
    var profileInitials: String = ""
    var profilePhotoURL: String? = nil

    var body: some View {
        HStack {
            Image("Logo")
                .resizable()
                .scaledToFit()
                .frame(width: 36, height: 36)
                .accessibilityLabel("FoundryMeet")

            Spacer()

            Button {
                showProfile = true
            } label: {
                ProfileAvatarView(
                    photoURL: profilePhotoURL,
                    initials: profileInitials,
                    size: 36
                )
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

/// Circular avatar used in the header and elsewhere. Supports https and local file URLs.
struct ProfileAvatarView: View {
    var photoURL: String?
    var initials: String = ""
    var size: CGFloat = 36

    var body: some View {
        Group {
            if let photoURL, let url = URL(string: photoURL), !photoURL.isEmpty {
                AsyncImage(url: url) { phase in
                    switch phase {
                    case .success(let image):
                        image
                            .resizable()
                            .scaledToFill()
                    case .failure:
                        fallback
                    case .empty:
                        ZStack {
                            fallback
                            ProgressView()
                                .controlSize(.mini)
                        }
                    @unknown default:
                        fallback
                    }
                }
            } else {
                fallback
            }
        }
        .frame(width: size, height: size)
        .clipShape(Circle())
        .overlay(Circle().stroke(AppColors.hairline, lineWidth: 1))
    }

    private var fallback: some View {
        ZStack {
            Circle().fill(AppColors.surfaceContainerLowest)
            if initials.isEmpty {
                Image(systemName: "person")
                    .font(.system(size: size * 0.36, weight: .medium))
                    .foregroundColor(AppColors.onSurface.opacity(0.85))
            } else {
                Text(initials.prefix(1).uppercased())
                    .font(.system(size: size * 0.36, weight: .semibold))
                    .foregroundColor(AppColors.onSurface.opacity(0.85))
            }
        }
    }
}

/// Presents the system share sheet from the current window (no blank intermediate sheet).
struct ActivitySharePresenter: UIViewControllerRepresentable {
    @Binding var isPresented: Bool
    let items: [Any]

    func makeUIViewController(context: Context) -> UIViewController {
        UIViewController()
    }

    func updateUIViewController(_ controller: UIViewController, context: Context) {
        guard isPresented, controller.presentedViewController == nil else {
            if !isPresented, controller.presentedViewController != nil {
                controller.dismiss(animated: true)
            }
            return
        }

        let activity = UIActivityViewController(activityItems: items, applicationActivities: nil)
        activity.completionWithItemsHandler = { _, _, _, _ in
            isPresented = false
        }
        if let popover = activity.popoverPresentationController {
            popover.sourceView = controller.view
            popover.sourceRect = CGRect(
                x: controller.view.bounds.midX,
                y: controller.view.bounds.midY,
                width: 0,
                height: 0
            )
            popover.permittedArrowDirections = []
        }
        controller.present(activity, animated: true)
    }
}

extension View {
    func hideSystemNavBar() -> some View {
        self
            .navigationBarTitleDisplayMode(.inline)
            .toolbar(.hidden, for: .navigationBar)
    }
}

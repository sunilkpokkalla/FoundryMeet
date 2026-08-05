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

/// Loads remote / local photos via URLSession so Firebase Storage and `file://`
/// URLs work reliably (AsyncImage often caches stale failures).
struct RemotePhotoView: View {
    var photoURL: String?
    var contentMode: ContentMode = .fill

    @State private var image: UIImage?
    @State private var didFail = false

    var showsFallback: Bool {
        let trimmed = photoURL?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
        return trimmed.isEmpty || didFail
    }

    var body: some View {
        Group {
            if let image {
                Image(uiImage: image)
                    .resizable()
                    .aspectRatio(contentMode: contentMode)
            } else if showsFallback {
                Color.clear
            } else {
                ZStack {
                    Color.gray.opacity(0.2)
                    ProgressView()
                        .controlSize(.mini)
                }
            }
        }
        .task(id: photoURL) {
            await loadImage()
        }
    }

    @MainActor
    private func loadImage() async {
        image = nil
        didFail = false

        let trimmed = photoURL?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
        guard !trimmed.isEmpty, let url = Self.resolvedURL(from: trimmed) else {
            didFail = true
            return
        }

        if url.isFileURL {
            if let loaded = UIImage(contentsOfFile: url.path) {
                image = loaded
            } else {
                didFail = true
            }
            return
        }

        do {
            var request = URLRequest(url: url)
            request.cachePolicy = .reloadIgnoringLocalCacheData
            let (data, response) = try await URLSession.shared.data(for: request)
            if let http = response as? HTTPURLResponse,
               !(200...299).contains(http.statusCode) {
                didFail = true
                return
            }
            guard let loaded = UIImage(data: data) else {
                didFail = true
                return
            }
            image = loaded
        } catch {
            didFail = true
        }
    }

    /// Accepts https URLs and file paths (`file://…` or absolute POSIX paths).
    static func resolvedURL(from string: String) -> URL? {
        if let url = URL(string: string), url.scheme != nil {
            return url
        }
        if string.hasPrefix("/") {
            return URL(fileURLWithPath: string)
        }
        return nil
    }
}

/// Circular avatar used in the header and elsewhere.
struct ProfileAvatarView: View {
    var photoURL: String?
    var initials: String = ""
    var size: CGFloat = 36
    /// Optional tint for the initials placeholder (Hub cards, profile sheets).
    var fallbackFill: Color? = nil
    var fallbackForeground: Color? = nil

    var body: some View {
        ZStack {
            fallback
            RemotePhotoView(photoURL: photoURL)
        }
        .frame(width: size, height: size)
        .clipShape(Circle())
        .overlay(Circle().stroke(AppColors.hairline, lineWidth: 1))
    }

    private var fallback: some View {
        ZStack {
            Circle().fill(fallbackFill ?? AppColors.surfaceContainerLowest)
            if initials.isEmpty {
                Image(systemName: "person")
                    .font(.system(size: size * 0.36, weight: .medium))
                    .foregroundColor(fallbackForeground ?? AppColors.onSurface.opacity(0.85))
            } else {
                Text(String(initials.prefix(2)).uppercased())
                    .font(.system(size: size * 0.34, weight: .semibold))
                    .foregroundColor(fallbackForeground ?? AppColors.onSurface.opacity(0.85))
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

/// In-app confirm sheet — replaces system alerts.
struct AppConfirmSheet: View {
    let title: String
    let message: String
    var cancelTitle: String = "Keep going"
    var confirmTitle: String = "Confirm"
    var isDestructive: Bool = false
    var onCancel: () -> Void
    var onConfirm: () -> Void

    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationStack {
            VStack(alignment: .leading, spacing: 20) {
                Text(title)
                    .font(.system(size: 22, weight: .semibold))
                    .tracking(-0.3)
                    .foregroundColor(AppColors.onSurface)

                Text(message)
                    .font(.system(size: 15))
                    .foregroundColor(AppColors.onSurfaceVariant)
                    .fixedSize(horizontal: false, vertical: true)

                Spacer(minLength: 12)

                VStack(spacing: 10) {
                    Button {
                        onConfirm()
                        dismiss()
                    } label: {
                        Text(confirmTitle)
                            .font(.system(size: 16, weight: .semibold))
                            .foregroundColor(isDestructive ? .white : AppColors.onPrimary)
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 15)
                            .background(isDestructive ? Color(hex: 0xB42318) : AppColors.primary)
                            .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
                    }
                    .buttonStyle(.plain)

                    Button {
                        onCancel()
                        dismiss()
                    } label: {
                        Text(cancelTitle)
                            .font(.system(size: 15, weight: .medium))
                            .foregroundColor(AppColors.onSurface)
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 14)
                            .background(AppColors.surfaceContainerLowest)
                            .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
                            .overlay(
                                RoundedRectangle(cornerRadius: 12, style: .continuous)
                                    .stroke(AppColors.hairline, lineWidth: 1)
                            )
                    }
                    .buttonStyle(.plain)
                }
            }
            .padding(24)
            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
            .background(AppColors.surface.ignoresSafeArea())
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Close") {
                        onCancel()
                        dismiss()
                    }
                    .foregroundColor(AppColors.onSurfaceVariant)
                }
            }
        }
        .presentationDetents([.medium])
        .presentationDragIndicator(.visible)
    }
}

/// In-app form sheet with optional text fields — replaces system TextField alerts.
struct AppFormSheet: View {
    let title: String
    let message: String
    var fields: [AppFormField]
    var cancelTitle: String = "Cancel"
    var confirmTitle: String = "Save"
    var isDestructive: Bool = false
    var onCancel: () -> Void
    var onConfirm: () -> Void

    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 18) {
                    Text(title)
                        .font(.system(size: 22, weight: .semibold))
                        .tracking(-0.3)
                        .foregroundColor(AppColors.onSurface)

                    Text(message)
                        .font(.system(size: 15))
                        .foregroundColor(AppColors.onSurfaceVariant)
                        .fixedSize(horizontal: false, vertical: true)

                    ForEach(fields) { field in
                        VStack(alignment: .leading, spacing: 6) {
                            Text(field.label)
                                .font(.system(size: 13, weight: .medium))
                                .foregroundColor(AppColors.onSurfaceVariant)
                            Group {
                                if field.isSecure {
                                    SecureField(field.placeholder, text: field.text)
                                } else {
                                    TextField(field.placeholder, text: field.text)
                                        .textInputAutocapitalization(field.autocapitalize ? .sentences : .never)
                                        .keyboardType(field.keyboard)
                                }
                            }
                            .padding(14)
                            .background(AppColors.surfaceContainerLowest)
                            .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
                            .overlay(
                                RoundedRectangle(cornerRadius: 12, style: .continuous)
                                    .stroke(AppColors.hairline, lineWidth: 1)
                            )
                        }
                    }

                    VStack(spacing: 10) {
                        Button {
                            onConfirm()
                            dismiss()
                        } label: {
                            Text(confirmTitle)
                                .font(.system(size: 16, weight: .semibold))
                                .foregroundColor(isDestructive ? .white : AppColors.onPrimary)
                                .frame(maxWidth: .infinity)
                                .padding(.vertical, 15)
                                .background(isDestructive ? Color(hex: 0xB42318) : AppColors.primary)
                                .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
                        }
                        .buttonStyle(.plain)

                        Button {
                            onCancel()
                            dismiss()
                        } label: {
                            Text(cancelTitle)
                                .font(.system(size: 15, weight: .medium))
                                .foregroundColor(AppColors.onSurface)
                                .frame(maxWidth: .infinity)
                                .padding(.vertical, 14)
                                .background(AppColors.surfaceContainerLowest)
                                .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
                                .overlay(
                                    RoundedRectangle(cornerRadius: 12, style: .continuous)
                                        .stroke(AppColors.hairline, lineWidth: 1)
                                )
                        }
                        .buttonStyle(.plain)
                    }
                    .padding(.top, 8)
                }
                .padding(24)
            }
            .background(AppColors.surface.ignoresSafeArea())
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Close") {
                        onCancel()
                        dismiss()
                    }
                    .foregroundColor(AppColors.onSurfaceVariant)
                }
            }
        }
        .presentationDetents([.medium, .large])
        .presentationDragIndicator(.visible)
    }
}

struct AppFormField: Identifiable {
    var id: String { label }
    let label: String
    let placeholder: String
    let text: Binding<String>
    var keyboard: UIKeyboardType = .default
    var autocapitalize: Bool = true
    var isSecure: Bool = false
}

extension View {
    func hideSystemNavBar() -> some View {
        self
            .navigationBarTitleDisplayMode(.inline)
            .toolbar(.hidden, for: .navigationBar)
    }
}

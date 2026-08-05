import SwiftUI

/// Report / block sheet used from Hub, Discover, and Messages.
struct SafetyActionsSheet: View {
    let userId: String
    let userName: String
    var onFinished: ((String) -> Void)? = nil

    @ObservedObject private var repository = AppRepository.shared
    @Environment(\.dismiss) private var dismiss
    @State private var selectedReason: UserReport.Reason = .spam
    @State private var details = ""
    @State private var isWorking = false
    @State private var errorMessage = ""
    @State private var mode: Mode = .menu

    private enum Mode {
        case menu
        case report
    }

    var body: some View {
        NavigationStack {
            ZStack {
                AppColors.surface.ignoresSafeArea()
                content
            }
            .navigationTitle(mode == .menu ? "Safety" : "Report")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button(mode == .menu ? "Close" : "Back") {
                        if mode == .report {
                            mode = .menu
                        } else {
                            dismiss()
                        }
                    }
                }
            }
        }
    }

    @ViewBuilder
    private var content: some View {
        switch mode {
        case .menu:
            VStack(alignment: .leading, spacing: 16) {
                Text("Actions for \(userName)")
                    .font(.system(size: 15))
                    .foregroundColor(AppColors.onSurfaceVariant)
                    .padding(.horizontal, 24)
                    .padding(.top, 12)

                Button {
                    mode = .report
                } label: {
                    safetyRow(
                        title: "Report",
                        subtitle: "Flag spam, harassment, or a fake profile.",
                        icon: "exclamationmark.bubble",
                        destructive: false
                    )
                }
                .buttonStyle(.plain)

                Button {
                    Task { await block() }
                } label: {
                    safetyRow(
                        title: repository.isBlocked(userId) ? "Already blocked" : "Block",
                        subtitle: "Hide them from Discover, Hub, and new requests.",
                        icon: "hand.raised.fill",
                        destructive: true
                    )
                }
                .buttonStyle(.plain)
                .disabled(repository.isBlocked(userId) || isWorking)

                if !errorMessage.isEmpty {
                    Text(errorMessage)
                        .font(.system(size: 13))
                        .foregroundColor(.red)
                        .padding(.horizontal, 24)
                }

                Spacer()
            }
        case .report:
            VStack(alignment: .leading, spacing: 18) {
                Text("Why are you reporting \(userName)?")
                    .font(.system(size: 15))
                    .foregroundColor(AppColors.onSurfaceVariant)

                VStack(spacing: 8) {
                    ForEach(UserReport.Reason.allCases) { reason in
                        Button {
                            selectedReason = reason
                        } label: {
                            HStack {
                                Text(reason.title)
                                    .font(.system(size: 15, weight: .medium))
                                    .foregroundColor(AppColors.onSurface)
                                Spacer()
                                if selectedReason == reason {
                                    Image(systemName: "checkmark.circle.fill")
                                        .foregroundColor(AppColors.primary)
                                }
                            }
                            .padding(14)
                            .background(AppColors.surfaceContainerLowest)
                            .cornerRadius(12)
                            .overlay(
                                RoundedRectangle(cornerRadius: 12)
                                    .stroke(
                                        selectedReason == reason ? AppColors.primary.opacity(0.35) : AppColors.hairline,
                                        lineWidth: 1
                                    )
                            )
                        }
                        .buttonStyle(.plain)
                    }
                }

                TextField("Optional details", text: $details, axis: .vertical)
                    .lineLimit(3...5)
                    .padding(14)
                    .background(AppColors.surfaceContainerLowest)
                    .cornerRadius(12)

                if !errorMessage.isEmpty {
                    Text(errorMessage)
                        .font(.system(size: 13))
                        .foregroundColor(.red)
                }

                Button {
                    Task { await report() }
                } label: {
                    HStack {
                        if isWorking { ProgressView().tint(AppColors.onPrimary) }
                        Text("Submit report")
                            .font(.system(size: 16, weight: .semibold))
                    }
                    .foregroundColor(AppColors.onPrimary)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 16)
                    .background(AppColors.primary)
                    .cornerRadius(12)
                }
                .disabled(isWorking)

                Spacer()
            }
            .padding(24)
        }
    }

    private func safetyRow(title: String, subtitle: String, icon: String, destructive: Bool) -> some View {
        HStack(alignment: .top, spacing: 14) {
            Image(systemName: icon)
                .font(.system(size: 18, weight: .semibold))
                .foregroundColor(destructive ? .red : AppColors.primary)
                .frame(width: 28)
            VStack(alignment: .leading, spacing: 4) {
                Text(title)
                    .font(.system(size: 16, weight: .semibold))
                    .foregroundColor(destructive ? .red : AppColors.onSurface)
                Text(subtitle)
                    .font(.system(size: 13))
                    .foregroundColor(AppColors.onSurfaceVariant)
                    .fixedSize(horizontal: false, vertical: true)
            }
            Spacer(minLength: 0)
        }
        .padding(16)
        .background(AppColors.surfaceContainerLowest)
        .cornerRadius(14)
        .padding(.horizontal, 20)
    }

    private func report() async {
        isWorking = true
        errorMessage = ""
        defer { isWorking = false }
        do {
            try await repository.reportUser(
                userId: userId,
                userName: userName,
                reason: selectedReason,
                details: details
            )
            onFinished?("Thanks — we received your report.")
            dismiss()
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    private func block() async {
        isWorking = true
        errorMessage = ""
        defer { isWorking = false }
        do {
            try await repository.blockUser(userId: userId, userName: userName)
            onFinished?("\(userName) is blocked.")
            dismiss()
        } catch {
            errorMessage = error.localizedDescription
        }
    }
}

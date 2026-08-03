import SwiftUI

/// City picker backed by MapKit autocomplete. Typing is always accepted, so a
/// place nobody can look up — or a dead network — never blocks the form.
struct LocationField: View {
    @Binding var place: ResolvedPlace?
    var placeholder: String = "e.g. San Francisco, CA"

    @StateObject private var search = LocationSearchService()
    @State private var query = ""
    @State private var debounce: Task<Void, Never>?
    @State private var isResolving = false
    @FocusState private var isFocused: Bool

    private var showsSuggestions: Bool {
        isFocused && !query.trimmingCharacters(in: .whitespaces).isEmpty
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack(spacing: 10) {
                TextField(placeholder, text: $query)
                    .font(.system(size: 16))
                    .foregroundColor(AppColors.onSurface)
                    .focused($isFocused)
                    .autocorrectionDisabled()
                    .submitLabel(.done)
                    .onSubmit { isFocused = false }

                if isResolving || search.isSearching {
                    ProgressView().scaleEffect(0.7)
                } else if !query.isEmpty {
                    Button {
                        clear()
                    } label: {
                        Image(systemName: "xmark.circle.fill")
                            .foregroundColor(AppColors.onSurfaceVariant.opacity(0.6))
                    }
                    .buttonStyle(.plain)
                    .accessibilityLabel("Clear location")
                }

                Image(systemName: place?.hasCoordinates == true ? "mappin.circle.fill" : "magnifyingglass")
                    .foregroundColor(place?.hasCoordinates == true ? AppColors.secondary : AppColors.onSurfaceVariant)
            }
            .padding()
            .background(AppColors.surfaceContainerLowest)
            .cornerRadius(12)
            .overlay(
                RoundedRectangle(cornerRadius: 12)
                    .stroke(AppColors.secondary.opacity(0.2), lineWidth: 2)
            )

            if showsSuggestions {
                VStack(spacing: 0) {
                    suggestionRow(
                        title: ResolvedPlace.remote.displayName,
                        subtitle: "Building from anywhere",
                        icon: "globe"
                    ) {
                        apply(.remote)
                    }

                    ForEach(search.suggestions.prefix(5)) { suggestion in
                        Divider().background(AppColors.hairline)
                        suggestionRow(
                            title: suggestion.title,
                            subtitle: suggestion.subtitle,
                            icon: "mappin.and.ellipse"
                        ) {
                            resolve(suggestion)
                        }
                    }
                }
                .background(AppColors.surfaceContainerLowest)
                .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
                .overlay(
                    RoundedRectangle(cornerRadius: 12, style: .continuous)
                        .stroke(AppColors.hairline, lineWidth: 1)
                )
            }
        }
        .onAppear {
            if query.isEmpty, let existing = place?.displayName {
                query = existing
            }
        }
        .onChange(of: query) { newValue in
            handleTyping(newValue)
        }
    }

    private func suggestionRow(
        title: String,
        subtitle: String,
        icon: String,
        action: @escaping () -> Void
    ) -> some View {
        Button(action: action) {
            HStack(spacing: 12) {
                Image(systemName: icon)
                    .font(.system(size: 14))
                    .foregroundColor(AppColors.secondary)
                    .frame(width: 20)

                VStack(alignment: .leading, spacing: 2) {
                    Text(title)
                        .font(.system(size: 15, weight: .medium))
                        .foregroundColor(AppColors.onSurface)
                        .lineLimit(1)
                    if !subtitle.isEmpty {
                        Text(subtitle)
                            .font(.system(size: 12))
                            .foregroundColor(AppColors.onSurfaceVariant)
                            .lineLimit(1)
                    }
                }

                Spacer(minLength: 0)
            }
            .padding(.horizontal, 14)
            .padding(.vertical, 12)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .accessibilityLabel(subtitle.isEmpty ? title : "\(title), \(subtitle)")
    }

    /// Typing counts as a free-text place straight away, and only gains
    /// coordinates if the user picks something off the list.
    private func handleTyping(_ newValue: String) {
        let trimmed = newValue.trimmingCharacters(in: .whitespacesAndNewlines)
        if trimmed != place?.displayName {
            place = trimmed.isEmpty ? nil : ResolvedPlace(displayName: trimmed)
        }

        debounce?.cancel()
        guard !trimmed.isEmpty else {
            search.clear()
            return
        }
        debounce = Task {
            try? await Task.sleep(nanoseconds: 300_000_000)
            guard !Task.isCancelled else { return }
            search.updateQuery(trimmed)
        }
    }

    private func resolve(_ suggestion: LocationSuggestion) {
        isResolving = true
        isFocused = false
        Task {
            let resolved = await search.resolve(suggestion)
            apply(resolved)
            isResolving = false
        }
    }

    private func apply(_ resolved: ResolvedPlace) {
        debounce?.cancel()
        place = resolved
        query = resolved.displayName
        isFocused = false
        search.clear()
    }

    private func clear() {
        debounce?.cancel()
        query = ""
        place = nil
        search.clear()
    }
}

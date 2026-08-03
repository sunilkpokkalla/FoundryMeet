import SwiftUI

/// Wrapping row of selectable pills. Used wherever a short, fixed set of
/// options has to stay identical between onboarding and the profile editor.
struct ChipGrid<Item: Identifiable & Hashable>: View {
    let items: [Item]
    let title: (Item) -> String
    var icon: ((Item) -> String)? = nil
    var isSelected: (Item) -> Bool
    var isDisabled: (Item) -> Bool = { _ in false }
    let onTap: (Item) -> Void
    var minWidth: CGFloat = 96

    var body: some View {
        LazyVGrid(
            columns: [GridItem(.adaptive(minimum: minWidth), spacing: 8)],
            alignment: .leading,
            spacing: 8
        ) {
            ForEach(items) { item in
                let selected = isSelected(item)
                let disabled = isDisabled(item)
                Button {
                    onTap(item)
                } label: {
                    HStack(spacing: 6) {
                        if let icon {
                            Image(systemName: icon(item))
                                .font(.system(size: 13))
                        }
                        Text(title(item))
                            .lineLimit(1)
                            .minimumScaleFactor(0.85)
                    }
                    .font(.system(size: 14, weight: .medium))
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 12)
                    .padding(.horizontal, 6)
                    .background(selected ? AppColors.secondary : AppColors.surfaceContainer)
                    .foregroundColor(selected ? AppColors.onSecondary : AppColors.onSurface)
                    .opacity(disabled ? 0.4 : 1)
                    .cornerRadius(20)
                }
                .buttonStyle(.plain)
                .disabled(disabled)
                .accessibilityAddTraits(selected ? [.isButton, .isSelected] : .isButton)
            }
        }
    }
}

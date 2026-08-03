import SwiftUI

struct LegalDocumentView: View {
    let document: LegalDocument
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationStack {
            ScrollView {
                Text(document.body)
                    .font(.system(size: 15))
                    .foregroundColor(AppColors.onSurface)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(24)
            }
            .background(AppColors.surface.ignoresSafeArea())
            .navigationTitle(document.title)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Close") { dismiss() }
                }
                ToolbarItem(placement: .primaryAction) {
                    Link(destination: document.url) {
                        Image(systemName: "safari")
                    }
                    .accessibilityLabel("Open in browser")
                }
            }
        }
    }
}

import SwiftUI

struct MatchHistoryView: View {
    var body: some View {
        NavigationView {
            ZStack {
                AppColors.surface.ignoresSafeArea()
                
                ScrollView {
                    VStack(spacing: 16) {
                        ForEach(0..<10) { index in
                            NavigationLink(destination: Text("Notes for Match \(index)")) {
                                HStack(spacing: 16) {
                                    Circle()
                                        .fill(AppColors.secondary.opacity(0.1))
                                        .frame(width: 56, height: 56)
                                        .overlay(
                                            Image(systemName: "person.fill")
                                                .foregroundColor(AppColors.secondary)
                                        )
                                    
                                    VStack(alignment: .leading, spacing: 4) {
                                        Text("Previous Match \(index + 1)")
                                            .font(.system(size: 16, weight: .semibold))
                                            .foregroundColor(AppColors.onSurface)
                                        Text("Met on July \(10 + index)")
                                            .font(.system(size: 14, weight: .regular))
                                            .foregroundColor(AppColors.onSurfaceVariant)
                                    }
                                    Spacer()
                                    Image(systemName: "chevron.right")
                                        .foregroundColor(AppColors.onSurfaceVariant.opacity(0.5))
                                }
                                .padding(16)
                                .background(AppColors.surfaceContainerLowest)
                                .cornerRadius(16)
                                .shadow(color: Color.black.opacity(0.02), radius: 8, x: 0, y: 2)
                            }
                        }
                    }
                    .padding(20)
                }
            }
            .navigationTitle("Match History")
        }
    }
}

struct MatchHistoryView_Previews: PreviewProvider {
    static var previews: some View {
        MatchHistoryView()
    }
}

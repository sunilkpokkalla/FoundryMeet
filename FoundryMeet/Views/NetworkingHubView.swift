import SwiftUI

struct NetworkingHubView: View {
    var body: some View {
        NavigationView {
            ZStack {
                AppColors.surface.ignoresSafeArea()
                
                ScrollView {
                    LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: 16) {
                        ForEach(0..<8) { index in
                            VStack(spacing: 12) {
                                Circle()
                                    .fill(AppColors.secondary.opacity(0.1))
                                    .frame(width: 80, height: 80)
                                    .overlay(
                                        Image(systemName: "person.2.fill")
                                            .resizable()
                                            .scaledToFit()
                                            .frame(width: 32)
                                            .foregroundColor(AppColors.secondary)
                                    )
                                
                                VStack(spacing: 4) {
                                    Text("Builder \(index + 1)")
                                        .font(.system(size: 16, weight: .semibold))
                                        .foregroundColor(AppColors.onSurface)
                                    
                                    Text("Fintech / AI")
                                        .font(.system(size: 12, weight: .regular))
                                        .foregroundColor(AppColors.onSurfaceVariant)
                                }
                            }
                            .padding(20)
                            .frame(maxWidth: .infinity)
                            .background(AppColors.surfaceContainerLowest)
                            .cornerRadius(16)
                            .shadow(color: Color.black.opacity(0.04), radius: 10, x: 0, y: 4)
                        }
                    }
                    .padding(20)
                }
            }
            .navigationTitle("Foundry Hub")
        }
    }
}

struct NetworkingHubView_Previews: PreviewProvider {
    static var previews: some View {
        NetworkingHubView()
    }
}

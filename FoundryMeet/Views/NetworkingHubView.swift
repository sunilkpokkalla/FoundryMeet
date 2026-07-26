import SwiftUI

struct BuilderProfile: Identifiable {
    let id = UUID()
    let name: String
    let role: String
    let industry: String
    let initials: String
    let color: Color
}

struct NetworkingHubView: View {
    let builders: [BuilderProfile] = [
        BuilderProfile(name: "Sarah Chen", role: "Technical Founder", industry: "AI / Fintech", initials: "SC", color: Color(hex: 0x4a90e2)),
        BuilderProfile(name: "Marcus Johnson", role: "Growth Lead", industry: "SaaS / B2B", initials: "MJ", color: Color(hex: 0xe24a4a)),
        BuilderProfile(name: "Elena Rodriguez", role: "Product Designer", industry: "Healthtech", initials: "ER", color: Color(hex: 0x4ae290)),
        BuilderProfile(name: "David Kim", role: "Data Scientist", industry: "Machine Learning", initials: "DK", color: Color(hex: 0x904ae2)),
        BuilderProfile(name: "Priya Patel", role: "CEO", industry: "EdTech", initials: "PP", color: Color(hex: 0xe2904a)),
        BuilderProfile(name: "Alex Thompson", role: "Backend Engineer", industry: "Web3 / Crypto", initials: "AT", color: Color(hex: 0x4ae2d9)),
        BuilderProfile(name: "James Wilson", role: "Marketing VP", industry: "E-commerce", initials: "JW", color: Color(hex: 0xe24a90)),
        BuilderProfile(name: "Nina Simone", role: "Operations", industry: "Logistics", initials: "NS", color: Color(hex: 0xa9e24a))
    ]
    
    var body: some View {
        NavigationView {
            ZStack {
                AppColors.surface.ignoresSafeArea()
                
                ScrollView {
                    LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: 16) {
                        ForEach(builders) { builder in
                            VStack(spacing: 12) {
                                Circle()
                                    .fill(builder.color.opacity(0.15))
                                    .frame(width: 80, height: 80)
                                    .overlay(
                                        Text(builder.initials)
                                            .font(.system(size: 28, weight: .bold))
                                            .foregroundColor(builder.color)
                                    )
                                
                                VStack(spacing: 4) {
                                    Text(builder.name)
                                        .font(.system(size: 16, weight: .semibold))
                                        .foregroundColor(AppColors.onSurface)
                                        .lineLimit(1)
                                        .minimumScaleFactor(0.8)
                                    
                                    Text(builder.role)
                                        .font(.system(size: 12, weight: .medium))
                                        .foregroundColor(AppColors.secondary)
                                        .lineLimit(1)
                                        .minimumScaleFactor(0.8)
                                    
                                    Text(builder.industry)
                                        .font(.system(size: 11, weight: .regular))
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
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Image("Logo")
                        .resizable()
                        .scaledToFill()
                        .frame(width: 36, height: 36)
                        .clipShape(Circle())
                        .overlay(Circle().stroke(Color.gray.opacity(0.1), lineWidth: 1))
                        .padding(.leading, 8)
                }
                ToolbarItem(placement: .principal) {
                    Text("Foundry Hub")
                        .font(.system(size: 20, weight: .bold))
                        .foregroundColor(AppColors.onSurface)
                }
            }
        }
    }
}

struct NetworkingHubView_Previews: PreviewProvider {
    static var previews: some View {
        NetworkingHubView()
    }
}

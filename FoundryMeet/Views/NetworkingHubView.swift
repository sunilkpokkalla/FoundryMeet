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
    @State private var selectedBuilder: BuilderProfile? = nil
    
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
                            Button(action: {
                                selectedBuilder = builder
                            }) {
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
                            .buttonStyle(PlainButtonStyle())
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
                        .scaledToFit()
                        .frame(width: 28, height: 28)
                        .padding(.leading, 8)
                }
                ToolbarItem(placement: .principal) {
                    Text("Foundry Hub")
                        .font(.system(size: 20, weight: .bold))
                        .foregroundColor(AppColors.onSurface)
                }
            }
            .sheet(item: $selectedBuilder) { builder in
                BuilderDetailView(builder: builder)
            }
        }
    }
}

struct BuilderDetailView: View {
    var builder: BuilderProfile
    @Environment(\.presentationMode) var presentationMode
    
    var body: some View {
        NavigationView {
            ZStack {
                AppColors.surface.ignoresSafeArea()
                
                VStack(spacing: 24) {
                    Circle()
                        .fill(builder.color.opacity(0.15))
                        .frame(width: 120, height: 120)
                        .overlay(
                            Text(builder.initials)
                                .font(.system(size: 40, weight: .bold))
                                .foregroundColor(builder.color)
                        )
                        .padding(.top, 40)
                    
                    VStack(spacing: 8) {
                        Text(builder.name)
                            .font(.system(size: 28, weight: .bold))
                            .foregroundColor(AppColors.onSurface)
                        
                        Text(builder.role)
                            .font(.system(size: 18, weight: .medium))
                            .foregroundColor(AppColors.secondary)
                        
                        Text(builder.industry)
                            .font(.system(size: 16, weight: .regular))
                            .foregroundColor(AppColors.onSurfaceVariant)
                    }
                    
                    VStack(alignment: .leading, spacing: 12) {
                        Text("ABOUT")
                            .font(.system(size: 12, weight: .bold))
                            .foregroundColor(AppColors.onSurfaceVariant)
                        
                        Text("Looking to connect with like-minded individuals in the \(builder.industry) space. Passionate about building products that scale.")
                            .font(.system(size: 16))
                            .foregroundColor(AppColors.onSurface)
                            .lineSpacing(4)
                    }
                    .padding(20)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .background(AppColors.surfaceContainerLow)
                    .cornerRadius(16)
                    .padding(.horizontal, 24)
                    
                    Spacer()
                    
                    HStack(spacing: 16) {
                        Button(action: {}) {
                            HStack {
                                Image(systemName: "message.fill")
                                Text("Message")
                                    .font(.system(size: 16, weight: .semibold))
                            }
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 16)
                            .background(AppColors.surfaceContainerHigh)
                            .foregroundColor(AppColors.onSurface)
                            .cornerRadius(12)
                        }
                        
                        Button(action: {}) {
                            HStack {
                                Image(systemName: "calendar")
                                Text("Schedule Chat")
                                    .font(.system(size: 16, weight: .semibold))
                            }
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 16)
                            .background(AppColors.primary)
                            .foregroundColor(AppColors.onPrimary)
                            .cornerRadius(12)
                        }
                    }
                    .padding(.horizontal, 24)
                    .padding(.bottom, 24)
                }
            }
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button(action: {
                        presentationMode.wrappedValue.dismiss()
                    }) {
                        Image(systemName: "xmark.circle.fill")
                            .foregroundColor(AppColors.onSurfaceVariant)
                            .font(.system(size: 24))
                    }
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

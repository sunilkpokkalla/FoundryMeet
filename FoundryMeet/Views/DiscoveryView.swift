import SwiftUI

struct DiscoveryView: View {
    let mockProfiles = [
        (name: "Sarah Chen", role: "CTO @ Stealth AI", imgUrl: "https://lh3.googleusercontent.com/aida-public/AB6AXuA0QfBeBm1DioWiMlUSwaNwhkst_KPXGv2hscKZ2WCivesiC-ZRg8rn7JQFo1RjP_A9hbX26eOk7mEfxWofkPWxOji9sb8uLBOhotCKhc_rSfmXtqMhdrSxgVJkINqhpUT9dEYXN4r0iSz6ThAj72IKacQNHzUg_n-QsoKhhmFdFyhnKE7cZpOmD1WXAkKByP6UttP7z8BFt6BBTIyvpa3qmuB8_C4BY3BCoDvveSHfXMKYefVvbZfp1D-kqG0sq5xTW4JT0Z2QsNg", desc: "Potential GTM partners and Series A insights from founders who've scaled to $10M ARR.", tags: ["Natural Language Processing", "Cloud Infrastructure", "Scaling Teams"]),
        (name: "Marcus Aris", role: "CEO @ Bloom Logistics", imgUrl: "https://lh3.googleusercontent.com/aida-public/AB6AXuBCtE5qu2rf2QU80DNGHCzWZ-AUgsifbN4BMvaOdZSLRFmeki7ZYM0JROldW9HKvoS1GPaoFUTwgYmTrDBWCv716Stg_0q8kl7EyI8MhjlzzOrxQ8a8YUfsbdkTeXDPhTD5bxusQN7mQcm0gZAkKIfP4bntsMxF21ixvM_CUU_ipbTMtXy4I87Bo78BUGpmJnKMPrBmIHjd-JDVgqIqJ2unLKKdSOkIfBbjbzaW216WKUxWJPBT24Vvgddbap3hKPkPMOBY9rQJo7U", desc: "Mentoring early-stage founders in the logistics space and exploring sustainable packaging tech.", tags: ["Operations", "Supply Chain AI", "Series B Prep"])
    ]
    
    var body: some View {
        NavigationView {
            ZStack(alignment: .top) {
                AppColors.surface.ignoresSafeArea()
                
                ScrollView {
                    VStack(alignment: .leading, spacing: 16) {
                        
                        // Header text
                        VStack(alignment: .leading, spacing: 4) {
                            Text("Curated for you")
                                .font(.system(size: 24, weight: .semibold))
                                .foregroundColor(AppColors.onSurface)
                            Text("High-signal matches based on your recent activity.")
                                .font(.system(size: 16))
                                .foregroundColor(AppColors.onSurfaceVariant)
                        }
                        .padding(.horizontal, 20)
                        .padding(.top, 16)
                        
                        // Filter ScrollView
                        ScrollView(.horizontal, showsIndicators: false) {
                            HStack(spacing: 8) {
                                FilterChip(text: "Stage: Seed+", icon: "line.3.horizontal.decrease", isSelected: true)
                                FilterChip(text: "Goal: Fundraising", isSelected: false)
                                FilterChip(text: "Industry: AI/ML", isSelected: false)
                                FilterChip(text: "Location", isSelected: false)
                            }
                            .padding(.horizontal, 20)
                        }
                        
                        // Profile Cards
                        VStack(spacing: 24) {
                            ForEach(mockProfiles, id: \.name) { profile in
                                DiscoveryProfileCard(profile: profile)
                            }
                        }
                        .padding(.horizontal, 20)
                        .padding(.top, 8)
                        .padding(.bottom, 40)
                    }
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
                ToolbarItem(placement: .navigationBarTrailing) {
                    Image(systemName: "person.crop.circle.fill")
                        .resizable()
                        .frame(width: 32, height: 32)
                        .foregroundColor(.gray)
                }
            }
        }
    }
}

struct FilterChip: View {
    var text: String
    var icon: String? = nil
    var isSelected: Bool
    
    var body: some View {
        HStack(spacing: 6) {
            if let icon = icon {
                Image(systemName: icon)
                    .font(.system(size: 14))
            }
            Text(text)
                .font(.system(size: 14, weight: .medium))
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 8)
        .background(isSelected ? Color(hex: 0xffdb94) : AppColors.surfaceContainerHighest)
        .foregroundColor(isSelected ? Color(hex: 0x795f24) : AppColors.onSurfaceVariant)
        .cornerRadius(20)
    }
}

struct DiscoveryProfileCard: View {
    var profile: (name: String, role: String, imgUrl: String, desc: String, tags: [String])
    
    var body: some View {
        VStack(spacing: 0) {
            // Image Header
            ZStack(alignment: .bottomLeading) {
                AsyncImage(url: URL(string: profile.imgUrl)) { image in
                    image
                        .resizable()
                        .scaledToFill()
                } placeholder: {
                    Color.gray.opacity(0.3)
                }
                .frame(height: 192)
                .clipped()
                
                // Gradient overlay
                LinearGradient(
                    colors: [Color.black.opacity(0.7), Color.clear],
                    startPoint: .bottom,
                    endPoint: .top
                )
                .frame(height: 120)
                
                HStack {
                    VStack(alignment: .leading, spacing: 4) {
                        Text(profile.name)
                            .font(.system(size: 20, weight: .bold))
                            .foregroundColor(.white)
                        Text(profile.role)
                            .font(.system(size: 16))
                            .foregroundColor(.white.opacity(0.9))
                    }
                    Spacer()
                    HStack(spacing: 4) {
                        Circle()
                            .fill(Color(hex: 0xc86c00))
                            .frame(width: 8, height: 8)
                        Text("Active")
                            .font(.system(size: 12, weight: .bold))
                            .foregroundColor(.white)
                    }
                    .padding(.horizontal, 12)
                    .padding(.vertical, 6)
                    .background(Color(hex: 0x010000).opacity(0.2))
                    .cornerRadius(12)
                }
                .padding(24)
            }
            
            // Content
            VStack(alignment: .leading, spacing: 20) {
                VStack(alignment: .leading, spacing: 12) {
                    Text("TOP EXPERTISE")
                        .font(.system(size: 12, weight: .bold))
                        .foregroundColor(AppColors.onSurfaceVariant)
                    
                    // Tags
                    ScrollView(.horizontal, showsIndicators: false) {
                        HStack {
                            ForEach(profile.tags, id: \.self) { tag in
                                Text(tag)
                                    .font(.system(size: 12, weight: .medium))
                                    .padding(.horizontal, 12)
                                    .padding(.vertical, 6)
                                    .background(AppColors.surfaceContainer)
                                    .foregroundColor(AppColors.onSurfaceVariant)
                                    .cornerRadius(16)
                            }
                        }
                    }
                }
                
                VStack(alignment: .leading, spacing: 8) {
                    Text("LOOKING FOR")
                        .font(.system(size: 12, weight: .bold))
                        .foregroundColor(Color(hex: 0x5a4309))
                    
                    Text(profile.desc)
                        .font(.system(size: 16))
                        .foregroundColor(AppColors.onSurface)
                }
                .padding(16)
                .background(AppColors.surfaceContainerLow)
                .cornerRadius(12)
                
                HStack(spacing: 12) {
                    Button(action: {}) {
                        HStack {
                            Image(systemName: "cup.and.saucer.fill")
                            Text("Request Coffee Chat")
                                .font(.system(size: 14, weight: .medium))
                        }
                        .foregroundColor(AppColors.onPrimary)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 16)
                        .background(AppColors.primary)
                        .cornerRadius(12)
                    }
                    
                    Button(action: {}) {
                        Image(systemName: "xmark")
                            .foregroundColor(AppColors.onSurface)
                            .frame(width: 56, height: 56)
                            .background(AppColors.surfaceContainerHighest)
                            .cornerRadius(12)
                    }
                }
            }
            .padding(24)
            .background(AppColors.surfaceContainerLowest)
        }
        .cornerRadius(16)
        .shadow(color: Color.black.opacity(0.04), radius: 20, x: 0, y: 4)
    }
}

struct DiscoveryView_Previews: PreviewProvider {
    static var previews: some View {
        DiscoveryView()
    }
}

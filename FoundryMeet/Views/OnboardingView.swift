import SwiftUI

struct OnboardingView: View {
    @Binding var isOnboardingCompleted: Bool
    @State private var selectedRole: String? = nil
    
    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            // Progress Header
            VStack(spacing: 8) {
                HStack {
                    Text("STEP 1 OF 4")
                        .font(.system(size: 12, weight: .bold))
                        .foregroundColor(AppColors.onSurfaceVariant)
                    Spacer()
                    Text("FoundryMeet")
                        .font(.system(size: 12, weight: .bold))
                        .foregroundColor(AppColors.secondary)
                }
                
                GeometryReader { geometry in
                    ZStack(alignment: .leading) {
                        Capsule().frame(width: geometry.size.width, height: 4)
                            .foregroundColor(AppColors.surfaceContainer)
                        Capsule().frame(width: geometry.size.width * 0.25, height: 4)
                            .foregroundColor(AppColors.secondary)
                    }
                }
                .frame(height: 4)
            }
            .padding(.horizontal, 24)
            .padding(.top, 24)
            
            ScrollView {
                VStack(alignment: .leading, spacing: 32) {
                    VStack(alignment: .leading, spacing: 8) {
                        Text("Tell us your story")
                            .font(.system(size: 32, weight: .bold))
                            .foregroundColor(AppColors.onSurface)
                        
                        Text("\"Meet the people building the future.\"")
                            .font(.system(size: 16, weight: .regular))
                            .italic()
                            .foregroundColor(AppColors.onSurfaceVariant)
                    }
                    
                    VStack(alignment: .leading, spacing: 16) {
                        Text("What is your primary role?")
                            .font(.system(size: 14, weight: .medium))
                            .foregroundColor(AppColors.onSurfaceVariant)
                        
                        VStack(spacing: 12) {
                            RoleOptionCard(
                                title: "Founder",
                                subtitle: "Visionary and strategist",
                                icon: "rocket",
                                isSelected: selectedRole == "Founder"
                            ) { selectedRole = "Founder" }
                            
                            RoleOptionCard(
                                title: "Builder",
                                subtitle: "Engineer or Designer",
                                icon: "wrench.and.screwdriver",
                                isSelected: selectedRole == "Builder"
                            ) { selectedRole = "Builder" }
                            
                            RoleOptionCard(
                                title: "Early Hire",
                                subtitle: "First 10 employees",
                                icon: "person.3",
                                isSelected: selectedRole == "Early Hire"
                            ) { selectedRole = "Early Hire" }
                        }
                    }
                }
                .padding(24)
            }
            
            // Footer
            VStack {
                Button(action: {
                    withAnimation {
                        isOnboardingCompleted = true
                    }
                }) {
                    Text("Continue")
                        .font(.system(size: 16, weight: .semibold))
                        .foregroundColor(AppColors.onPrimary)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 16)
                        .background(AppColors.primary)
                        .cornerRadius(12)
                }
                .padding(24)
            }
            .background(AppColors.surface.opacity(0.9))
        }
        .background(AppColors.background.ignoresSafeArea())
    }
}

struct RoleOptionCard: View {
    var title: String
    var subtitle: String
    var icon: String
    var isSelected: Bool
    var action: () -> Void
    
    var body: some View {
        Button(action: action) {
            HStack(spacing: 16) {
                ZStack {
                    Circle()
                        .fill(isSelected ? AppColors.secondary : AppColors.surfaceContainerHighest)
                        .frame(width: 48, height: 48)
                    
                    Image(systemName: icon)
                        .foregroundColor(isSelected ? AppColors.onSecondary : AppColors.primary)
                }
                
                VStack(alignment: .leading, spacing: 4) {
                    Text(title)
                        .font(.system(size: 20, weight: .semibold))
                        .foregroundColor(AppColors.onSurface)
                    Text(subtitle)
                        .font(.system(size: 14, weight: .regular))
                        .foregroundColor(AppColors.onSurfaceVariant)
                }
                
                Spacer()
                
                if isSelected {
                    Image(systemName: "checkmark.circle.fill")
                        .foregroundColor(AppColors.secondary)
                }
            }
            .padding(20)
            .background(isSelected ? Color(hex: 0xffdb94) : AppColors.surfaceContainerLow)
            .cornerRadius(12)
        }
        .buttonStyle(PlainButtonStyle())
    }
}

struct OnboardingView_Previews: PreviewProvider {
    static var previews: some View {
        OnboardingView(isOnboardingCompleted: .constant(false))
    }
}

import SwiftUI

struct OnboardingView: View {
    @Binding var isOnboardingCompleted: Bool
    @ObservedObject private var repository = AppRepository.shared
    
    @State private var step = 1
    @State private var selectedRole: String? = nil
    @State private var location: String = ""
    @State private var selectedStage: String? = nil
    @State private var selectedSkills: Set<String> = []
    @State private var selectedGoal: String? = nil
    @State private var isSaving = false
    @State private var errorMessage = ""
    
    let stages = ["Idea", "Seed", "Series A+"]
    let skills = [
        ("Engineering", "curlybraces"),
        ("Design", "paintpalette"),
        ("Sales", "banknote"),
        ("Growth", "chart.line.uptrend.xyaxis"),
        ("Product", "cube.box"),
        ("Legal", "briefcase"),
        ("AI/ML", "brain")
    ]
    
    let goals = [
        ("Find a Cofounder", "hand.shake", "Search for partners with complementary skills and shared values."),
        ("Hire Early Team", "person.badge.plus", "Find the builders who will help you lay the first bricks."),
        ("Get Advice", "graduationcap", "Connect with experienced advisors and domain experts.")
    ]
    
    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            // Progress Header
            VStack(spacing: 8) {
                HStack {
                    Text("STEP \(step) OF 4")
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
                        Capsule().frame(width: geometry.size.width * CGFloat(step) / 4.0, height: 4)
                            .foregroundColor(AppColors.secondary)
                            .animation(.easeOut, value: step)
                    }
                }
                .frame(height: 4)
            }
            .padding(.horizontal, 24)
            .padding(.top, 24)
            
            ScrollView {
                VStack(alignment: .leading, spacing: 32) {
                    if step == 1 {
                        stepOneView
                    } else if step == 2 {
                        stepTwoView
                    } else if step == 3 {
                        stepThreeView
                    } else if step == 4 {
                        stepFourView
                    }
                }
                .padding(24)
            }
            
            // Footer
            HStack(spacing: 16) {
                if step > 1 {
                    Button(action: {
                        withAnimation {
                            step -= 1
                        }
                    }) {
                        Text("Back")
                            .font(.system(size: 16, weight: .semibold))
                            .foregroundColor(AppColors.onSurfaceVariant)
                            .padding(.vertical, 16)
                            .padding(.horizontal, 24)
                            .background(AppColors.surfaceContainerHigh)
                            .cornerRadius(12)
                    }
                }
                
                Button(action: {
                    if step < 4 {
                        withAnimation { step += 1 }
                    } else {
                        finishOnboarding()
                    }
                }) {
                    HStack {
                        if isSaving {
                            ProgressView()
                                .tint(step == 4 ? AppColors.onSecondary : AppColors.onPrimary)
                        } else {
                            if step == 4 {
                                Image(systemName: "sparkles")
                            }
                            Text(step == 4 ? "Start Matching" : "Continue")
                        }
                    }
                    .font(.system(size: 16, weight: .semibold))
                    .foregroundColor(step == 4 ? AppColors.onSecondary : AppColors.onPrimary)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 16)
                    .background(step == 4 ? AppColors.secondary : AppColors.primary)
                    .cornerRadius(12)
                }
                .disabled(isSaving)
            }
            .padding(24)
            .background(AppColors.surface.opacity(0.9))

            if !errorMessage.isEmpty {
                Text(errorMessage)
                    .font(.system(size: 13))
                    .foregroundColor(.red)
                    .padding(.horizontal, 24)
                    .padding(.bottom, 8)
            }
        }
        .background(AppColors.background.ignoresSafeArea())
    }

    private func finishOnboarding() {
        errorMessage = ""
        isSaving = true
        Task {
            do {
                try await repository.saveOnboarding(
                    role: selectedRole,
                    location: location,
                    stage: selectedStage,
                    skills: Array(selectedSkills).sorted(),
                    goal: selectedGoal
                )
                withAnimation { isOnboardingCompleted = true }
            } catch {
                errorMessage = error.localizedDescription
            }
            isSaving = false
        }
    }
    
    // MARK: - Step 1
    var stepOneView: some View {
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
                        title: "Founder", subtitle: "Visionary and strategist", icon: "rocket",
                        isSelected: selectedRole == "Founder"
                    ) { selectedRole = "Founder" }
                    
                    RoleOptionCard(
                        title: "Builder", subtitle: "Engineer or Designer", icon: "wrench.and.screwdriver",
                        isSelected: selectedRole == "Builder"
                    ) { selectedRole = "Builder" }
                    
                    RoleOptionCard(
                        title: "Early Hire", subtitle: "First 10 employees", icon: "person.3",
                        isSelected: selectedRole == "Early Hire"
                    ) { selectedRole = "Early Hire" }
                }
            }
        }
    }
    
    // MARK: - Step 2
    var stepTwoView: some View {
        VStack(alignment: .leading, spacing: 32) {
            VStack(alignment: .leading, spacing: 8) {
                Text("Context is key")
                    .font(.system(size: 32, weight: .bold))
                    .foregroundColor(AppColors.onSurface)
                
                Text("Where are you building, and how far along is the journey?")
                    .font(.system(size: 16, weight: .regular))
                    .foregroundColor(AppColors.onSurfaceVariant)
            }
            
            VStack(alignment: .leading, spacing: 24) {
                VStack(alignment: .leading, spacing: 12) {
                    Text("Base Location")
                        .font(.system(size: 14, weight: .medium))
                        .foregroundColor(AppColors.onSurfaceVariant)
                    
                    HStack {
                        TextField("e.g. San Francisco, CA", text: $location)
                            .font(.system(size: 16))
                            .foregroundColor(AppColors.onSurface)
                        Image(systemName: "location.fill")
                            .foregroundColor(AppColors.onSurfaceVariant)
                    }
                    .padding()
                    .background(AppColors.surfaceContainerLowest)
                    .cornerRadius(12)
                    .overlay(
                        RoundedRectangle(cornerRadius: 12)
                            .stroke(AppColors.secondary.opacity(0.2), lineWidth: 2)
                    )
                }
                
                VStack(alignment: .leading, spacing: 12) {
                    Text("Startup Stage")
                        .font(.system(size: 14, weight: .medium))
                        .foregroundColor(AppColors.onSurfaceVariant)
                    
                    HStack(spacing: 8) {
                        ForEach(stages, id: \.self) { stage in
                            Button(action: { selectedStage = stage }) {
                                Text(stage)
                                    .font(.system(size: 14, weight: .medium))
                                    .frame(maxWidth: .infinity)
                                    .padding(.vertical, 12)
                                    .background(selectedStage == stage ? AppColors.secondary : AppColors.surfaceContainer)
                                    .foregroundColor(selectedStage == stage ? AppColors.onSecondary : AppColors.onSurface)
                                    .cornerRadius(20)
                            }
                        }
                    }
                }
            }
        }
    }
    
    // MARK: - Step 3
    var stepThreeView: some View {
        VStack(alignment: .leading, spacing: 32) {
            VStack(alignment: .leading, spacing: 8) {
                Text("Your Superpowers")
                    .font(.system(size: 32, weight: .bold))
                    .foregroundColor(AppColors.onSurface)
                
                Text("Select the skills you bring to the table.")
                    .font(.system(size: 16, weight: .regular))
                    .foregroundColor(AppColors.onSurfaceVariant)
            }
            
            LazyVGrid(columns: [GridItem(.adaptive(minimum: 120), spacing: 12)], spacing: 12) {
                ForEach(skills, id: \.0) { skill in
                    let isSelected = selectedSkills.contains(skill.0)
                    Button(action: {
                        if isSelected {
                            selectedSkills.remove(skill.0)
                        } else {
                            selectedSkills.insert(skill.0)
                        }
                    }) {
                        HStack {
                            Image(systemName: skill.1)
                            Text(skill.0)
                        }
                        .font(.system(size: 14, weight: .medium))
                        .padding(.vertical, 10)
                        .padding(.horizontal, 16)
                        .frame(maxWidth: .infinity)
                        .background(isSelected ? AppColors.secondary : AppColors.surfaceContainerLow)
                        .foregroundColor(isSelected ? AppColors.onSecondary : AppColors.onSurface)
                        .cornerRadius(20)
                    }
                }
            }
        }
    }
    
    // MARK: - Step 4
    var stepFourView: some View {
        VStack(alignment: .leading, spacing: 32) {
            VStack(alignment: .leading, spacing: 8) {
                Text("The North Star")
                    .font(.system(size: 32, weight: .bold))
                    .foregroundColor(AppColors.onSurface)
                
                Text("What is your primary goal right now?")
                    .font(.system(size: 16, weight: .regular))
                    .foregroundColor(AppColors.onSurfaceVariant)
            }
            
            VStack(spacing: 12) {
                ForEach(goals, id: \.0) { goal in
                    GoalOptionCard(
                        title: goal.0, icon: goal.1, description: goal.2,
                        isSelected: selectedGoal == goal.0
                    ) { selectedGoal = goal.0 }
                }
            }
        }
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

struct GoalOptionCard: View {
    var title: String
    var icon: String
    var description: String
    var isSelected: Bool
    var action: () -> Void
    
    var body: some View {
        Button(action: action) {
            VStack(alignment: .leading, spacing: 12) {
                HStack {
                    Image(systemName: icon)
                        .foregroundColor(AppColors.secondary)
                        .font(.system(size: 20))
                    
                    Spacer()
                    
                    ZStack {
                        Circle()
                            .strokeBorder(isSelected ? AppColors.secondary : AppColors.secondary.opacity(0.3), lineWidth: 2)
                            .background(Circle().fill(isSelected ? AppColors.secondary : Color.clear))
                            .frame(width: 20, height: 20)
                        if isSelected {
                            Circle().fill(.white).frame(width: 8, height: 8)
                        }
                    }
                }
                
                VStack(alignment: .leading, spacing: 4) {
                    Text(title)
                        .font(.system(size: 18, weight: .semibold))
                        .foregroundColor(AppColors.onSurface)
                    Text(description)
                        .font(.system(size: 14, weight: .regular))
                        .foregroundColor(AppColors.onSurfaceVariant)
                        .multilineTextAlignment(.leading)
                }
            }
            .padding(20)
            .background(isSelected ? Color(hex: 0xffdb94).opacity(0.3) : AppColors.surfaceContainerLow)
            .cornerRadius(16)
        }
        .buttonStyle(PlainButtonStyle())
    }
}

struct OnboardingView_Previews: PreviewProvider {
    static var previews: some View {
        OnboardingView(isOnboardingCompleted: .constant(false))
    }
}

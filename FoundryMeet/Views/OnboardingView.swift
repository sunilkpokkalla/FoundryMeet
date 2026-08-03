import SwiftUI

struct OnboardingView: View {
    @Binding var isOnboardingCompleted: Bool
    @ObservedObject private var repository = AppRepository.shared
    
    @State private var step = 1
    @State private var selectedRole: FounderRole? = nil
    @State private var place: ResolvedPlace? = nil
    @State private var selectedStages: Set<StartupStage> = []
    @State private var selectedIndustry: Industry? = nil
    @State private var selectedSkills: Set<Skill> = []
    @State private var selectedGoal: NetworkingGoal? = nil
    @State private var isSaving = false
    @State private var errorMessage = ""
    
    /// Only the goals that make sense for the role picked in step 1.
    private var availableGoals: [NetworkingGoal] {
        selectedRole?.goals ?? []
    }

    private var availableStages: [StartupStage] {
        selectedRole?.stages ?? []
    }

    private var availableSkills: [Skill] {
        selectedRole?.skills ?? []
    }

    /// Everything these steps collect feeds matching, so none of them can be
    /// skipped.
    private var canContinue: Bool {
        switch step {
        case 1: return selectedRole != nil
        case 2: return place != nil && !selectedStages.isEmpty
        case 3: return !selectedSkills.isEmpty
        case 4: return selectedGoal != nil
        default: return true
        }
    }
    
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
                    .background((step == 4 ? AppColors.secondary : AppColors.primary).opacity(canContinue ? 1 : 0.5))
                    .cornerRadius(12)
                }
                .disabled(isSaving || !canContinue)
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
                    role: selectedRole?.rawValue,
                    place: place,
                    stages: availableStages.filter { selectedStages.contains($0) },
                    industry: selectedIndustry,
                    skills: availableSkills.filter { selectedSkills.contains($0) }.map(\.rawValue),
                    goal: selectedGoal?.rawValue
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

                LazyVGrid(
                    columns: [GridItem(.flexible(), spacing: 12), GridItem(.flexible(), spacing: 12)],
                    spacing: 12
                ) {
                    ForEach(FounderRole.allCases) { role in
                        RoleOptionCard(role: role, isSelected: selectedRole == role) {
                            select(role)
                        }
                    }
                }
            }
        }
    }

    /// Switching role can strip away answers that no longer apply.
    private func select(_ role: FounderRole) {
        selectedRole = role
        if let goal = selectedGoal, !role.goals.contains(goal) {
            selectedGoal = nil
        }
        selectedStages = role.retainingValidStages(from: selectedStages)
        selectedSkills = role.retainingValidSkills(from: selectedSkills)
    }

    private func toggle(_ stage: StartupStage) {
        guard let role = selectedRole else { return }
        selectedStages = role.toggling(stage, in: selectedStages)
    }
    
    // MARK: - Step 2
    var stepTwoView: some View {
        VStack(alignment: .leading, spacing: 32) {
            VStack(alignment: .leading, spacing: 8) {
                Text("Context is key")
                    .font(.system(size: 32, weight: .bold))
                    .foregroundColor(AppColors.onSurface)
                
                Text("Where you're based, and the kind of company you want to be around.")
                    .font(.system(size: 16, weight: .regular))
                    .foregroundColor(AppColors.onSurfaceVariant)
            }
            
            VStack(alignment: .leading, spacing: 24) {
                VStack(alignment: .leading, spacing: 12) {
                    Text("Base Location")
                        .font(.system(size: 14, weight: .medium))
                        .foregroundColor(AppColors.onSurfaceVariant)
                    
                    LocationField(place: $place)
                }
                
                VStack(alignment: .leading, spacing: 12) {
                    VStack(alignment: .leading, spacing: 4) {
                        Text(selectedRole?.stageLabel ?? "Stage")
                            .font(.system(size: 14, weight: .medium))
                            .foregroundColor(AppColors.onSurfaceVariant)

                        Text(selectedRole?.stageQuestion ?? "What stage are you at?")
                            .font(.system(size: 13))
                            .foregroundColor(AppColors.onSurfaceVariant.opacity(0.8))

                        if selectedRole?.allowsMultipleStages == true {
                            Text("Pick as many as apply.")
                                .font(.system(size: 12))
                                .foregroundColor(AppColors.onSurfaceVariant.opacity(0.7))
                        }
                    }

                    ChipGrid(
                        items: availableStages,
                        title: { $0.title },
                        isSelected: { selectedStages.contains($0) },
                        onTap: { toggle($0) }
                    )
                }

                VStack(alignment: .leading, spacing: 12) {
                    VStack(alignment: .leading, spacing: 4) {
                        Text("Industry")
                            .font(.system(size: 14, weight: .medium))
                            .foregroundColor(AppColors.onSurfaceVariant)

                        Text(selectedRole?.industryQuestion ?? "What space are you in?")
                            .font(.system(size: 13))
                            .foregroundColor(AppColors.onSurfaceVariant.opacity(0.8))
                    }

                    ChipGrid(
                        items: Industry.allCases,
                        title: { $0.title },
                        isSelected: { selectedIndustry == $0 },
                        onTap: { selectedIndustry = selectedIndustry == $0 ? nil : $0 }
                    )
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
                
                Text(selectedRole?.skillQuestion ?? "What do you bring to the table?")
                    .font(.system(size: 16, weight: .regular))
                    .foregroundColor(AppColors.onSurfaceVariant)
                    .fixedSize(horizontal: false, vertical: true)
            }

            VStack(alignment: .leading, spacing: 12) {
                HStack {
                    Text("Pick up to \(Skill.selectionLimit)")
                        .font(.system(size: 14, weight: .medium))
                        .foregroundColor(AppColors.onSurfaceVariant)
                    Spacer()
                    Text("\(selectedSkills.count) of \(Skill.selectionLimit)")
                        .font(.system(size: 13, weight: .medium))
                        .foregroundColor(atSkillLimit ? AppColors.secondary : AppColors.onSurfaceVariant.opacity(0.7))
                }

                ChipGrid(
                    items: availableSkills,
                    title: { $0.title },
                    icon: { $0.icon },
                    isSelected: { selectedSkills.contains($0) },
                    isDisabled: { atSkillLimit && !selectedSkills.contains($0) },
                    onTap: { selectedSkills = Skill.toggling($0, in: selectedSkills) },
                    minWidth: 132
                )
            }
        }
    }

    private var atSkillLimit: Bool {
        selectedSkills.count >= Skill.selectionLimit
    }
    
    // MARK: - Step 4
    var stepFourView: some View {
        VStack(alignment: .leading, spacing: 32) {
            VStack(alignment: .leading, spacing: 8) {
                Text("The North Star")
                    .font(.system(size: 32, weight: .bold))
                    .foregroundColor(AppColors.onSurface)
                
                Text(selectedRole.map { "What do you want out of the network as \(article(for: $0)) \($0.title)?" }
                    ?? "What is your primary goal right now?")
                    .font(.system(size: 16, weight: .regular))
                    .foregroundColor(AppColors.onSurfaceVariant)
                    .fixedSize(horizontal: false, vertical: true)
            }
            
            VStack(spacing: 12) {
                ForEach(availableGoals) { goal in
                    GoalOptionCard(
                        title: goal.title, icon: goal.icon, description: goal.detail,
                        isSelected: selectedGoal == goal
                    ) { selectedGoal = goal }
                }
            }
        }
    }

    private func article(for role: FounderRole) -> String {
        "AEIOU".contains(role.title.uppercased().prefix(1)) ? "an" : "a"
    }
}

struct RoleOptionCard: View {
    var role: FounderRole
    var isSelected: Bool
    var action: () -> Void

    var body: some View {
        Button(action: action) {
            VStack(alignment: .leading, spacing: 10) {
                HStack(alignment: .top) {
                    ZStack {
                        Circle()
                            .fill(isSelected ? AppColors.secondary : AppColors.surfaceContainerHighest)
                            .frame(width: 40, height: 40)

                        Image(systemName: role.icon)
                            .font(.system(size: 17))
                            .foregroundColor(isSelected ? AppColors.onSecondary : AppColors.primary)
                    }

                    Spacer(minLength: 0)

                    Image(systemName: "checkmark.circle.fill")
                        .foregroundColor(AppColors.secondary)
                        .opacity(isSelected ? 1 : 0)
                }

                VStack(alignment: .leading, spacing: 3) {
                    Text(role.title)
                        .font(.system(size: 16, weight: .semibold))
                        .foregroundColor(AppColors.onSurface)
                        .lineLimit(1)
                        .minimumScaleFactor(0.85)
                    Text(role.subtitle)
                        .font(.system(size: 12, weight: .regular))
                        .foregroundColor(AppColors.onSurfaceVariant)
                        .multilineTextAlignment(.leading)
                        .fixedSize(horizontal: false, vertical: true)
                }
            }
            .padding(16)
            .frame(maxWidth: .infinity, minHeight: 128, alignment: .topLeading)
            .background(isSelected ? Color(hex: 0xffdb94) : AppColors.surfaceContainerLow)
            .cornerRadius(12)
        }
        .buttonStyle(PlainButtonStyle())
        .accessibilityLabel("\(role.title). \(role.subtitle)")
        .accessibilityAddTraits(isSelected ? [.isSelected] : [])
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

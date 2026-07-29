import SwiftUI

struct SchedulingView: View {
    @State private var selectedDay = 0
    @State private var selectedTime: Int? = nil
    @State private var selectedSetting: SettingType = .inPerson
    @State private var talkingPoints: String = ""
    
    let days = [
        ("Tue", "14"), ("Wed", "15"), ("Thu", "16"), ("Fri", "17")
    ]
    
    let slots = [
        ("Morning", "9:00 AM"),
        ("Lunch", "12:30 PM"),
        ("Afternoon", "3:45 PM")
    ]
    
    enum SettingType {
        case inPerson, virtual, office
    }
    
    var body: some View {
        NavigationView {
            ZStack {
                AppColors.surface.ignoresSafeArea()
                
                ScrollView {
                    VStack(alignment: .leading, spacing: 32) {
                        
                        // Header Profile
                        VStack(alignment: .leading, spacing: 16) {
                            HStack(spacing: 16) {
                                ZStack(alignment: .bottomTrailing) {
                                    // Mock profile image
                                    Image(systemName: "person.crop.circle.fill")
                                        .resizable()
                                        .frame(width: 56, height: 56)
                                        .foregroundColor(.gray)
                                        .background(Circle().stroke(AppColors.surfaceContainerHigh, lineWidth: 2))
                                    
                                    ZStack {
                                        Circle().fill(AppColors.surface).frame(width: 18, height: 18)
                                        Image(systemName: "checkmark.circle.fill")
                                            .resizable()
                                            .frame(width: 14, height: 14)
                                            .foregroundColor(AppColors.secondary)
                                    }
                                }
                                
                                VStack(alignment: .leading, spacing: 4) {
                                    Text("ACCEPTED MATCH")
                                        .font(.system(size: 12, weight: .bold))
                                        .foregroundColor(AppColors.secondary)
                                        .kerning(1.2)
                                    
                                    Text("Coffee with Sarah")
                                        .font(.system(size: 24, weight: .bold))
                                        .foregroundColor(AppColors.onSurface)
                                }
                            }
                            
                            Text("You both have 3 overlapping gaps this week. Let's find a time that feels effortless.")
                                .font(.system(size: 15, weight: .regular))
                                .foregroundColor(AppColors.onSurfaceVariant)
                                .lineSpacing(4)
                        }
                        
                        // Days Selector
                        ScrollView(.horizontal, showsIndicators: false) {
                            HStack(spacing: 12) {
                                ForEach(0..<days.count, id: \.self) { index in
                                    Button(action: { selectedDay = index }) {
                                        VStack(spacing: 4) {
                                            Text(days[index].0)
                                                .font(.system(size: 12, weight: .medium))
                                            Text(days[index].1)
                                                .font(.system(size: 20, weight: .bold))
                                        }
                                        .padding(.vertical, 16)
                                        .padding(.horizontal, 24)
                                        .background(selectedDay == index ? AppColors.primary : AppColors.secondary.opacity(0.15))
                                        .foregroundColor(selectedDay == index ? AppColors.onPrimary : AppColors.onSurface)
                                        .cornerRadius(16)
                                    }
                                }
                            }
                        }
                        .padding(.horizontal, -24)
                        .padding(.horizontal, 24)
                        
                        // Suggested Slots
                        VStack(alignment: .leading, spacing: 16) {
                            HStack {
                                Text("SUGGESTED SLOTS")
                                    .font(.system(size: 12, weight: .bold))
                                    .foregroundColor(AppColors.onSurfaceVariant)
                                    .kerning(1.2)
                                Spacer()
                                Text("Shared Free Time")
                                    .font(.system(size: 10, weight: .medium))
                                    .padding(.horizontal, 8)
                                    .padding(.vertical, 4)
                                    .background(AppColors.secondary.opacity(0.1))
                                    .foregroundColor(AppColors.secondary)
                                    .cornerRadius(8)
                            }
                            
                            LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: 12) {
                                ForEach(0..<slots.count, id: \.self) { index in
                                    Button(action: { selectedTime = index }) {
                                        VStack(spacing: 4) {
                                            Text(slots[index].0)
                                                .font(.system(size: 12, weight: .medium))
                                                .foregroundColor(AppColors.onSurfaceVariant)
                                            Text(slots[index].1)
                                                .font(.system(size: 16, weight: .bold))
                                                .foregroundColor(AppColors.onSurface)
                                        }
                                        .frame(maxWidth: .infinity)
                                        .padding(.vertical, 16)
                                        .background(selectedTime == index ? AppColors.secondary.opacity(0.2) : AppColors.surfaceContainerLow)
                                        .cornerRadius(12)
                                        .overlay(
                                            RoundedRectangle(cornerRadius: 12)
                                                .stroke(selectedTime == index ? AppColors.secondary : Color.clear, lineWidth: 2)
                                        )
                                    }
                                }
                                
                                Button(action: { selectedTime = 3 }) {
                                    VStack(spacing: 4) {
                                        Image(systemName: "clock.badge.exclamationmark")
                                            .font(.system(size: 16))
                                            .foregroundColor(AppColors.onSurfaceVariant)
                                        Text("Custom")
                                            .font(.system(size: 14, weight: .medium))
                                            .foregroundColor(AppColors.onSurfaceVariant)
                                    }
                                    .frame(maxWidth: .infinity)
                                    .padding(.vertical, 16)
                                    .background(AppColors.surfaceContainerLowest)
                                    .cornerRadius(12)
                                    .overlay(
                                        RoundedRectangle(cornerRadius: 12)
                                            .stroke(AppColors.onSurfaceVariant.opacity(0.3), style: StrokeStyle(lineWidth: 2, dash: [4]))
                                    )
                                }
                            }
                        }
                        
                        // The Setting
                        VStack(alignment: .leading, spacing: 16) {
                            Text("THE SETTING")
                                .font(.system(size: 12, weight: .bold))
                                .foregroundColor(AppColors.onSurfaceVariant)
                                .kerning(1.2)
                            
                            HStack(spacing: 8) {
                                SettingButton(title: "In Person", icon: "cup.and.saucer", isSelected: selectedSetting == .inPerson) { selectedSetting = .inPerson }
                                SettingButton(title: "Virtual", icon: "video", isSelected: selectedSetting == .virtual) { selectedSetting = .virtual }
                                SettingButton(title: "Office", icon: "building.2", isSelected: selectedSetting == .office) { selectedSetting = .office }
                            }
                            
                            if selectedSetting == .inPerson {
                                HStack(spacing: 16) {
                                    Image(systemName: "photo.fill")
                                        .resizable()
                                        .frame(width: 48, height: 48)
                                        .foregroundColor(AppColors.surfaceContainerHigh)
                                        .background(AppColors.surfaceContainerHighest)
                                        .cornerRadius(8)
                                    
                                    VStack(alignment: .leading, spacing: 4) {
                                        Text("The Foundry Lab (Chelsea)")
                                            .font(.system(size: 14, weight: .semibold))
                                            .foregroundColor(AppColors.onSurface)
                                        Text("Sarah's favorite spot. 0.4 miles away.")
                                            .font(.system(size: 12, weight: .regular))
                                            .foregroundColor(AppColors.onSurfaceVariant)
                                    }
                                    Spacer()
                                    Image(systemName: "chevron.right")
                                        .foregroundColor(AppColors.onSurfaceVariant)
                                        .font(.system(size: 14, weight: .bold))
                                }
                                .padding(16)
                                .background(AppColors.secondary.opacity(0.15))
                                .cornerRadius(12)
                            }
                        }
                        
                        // Meeting Intent
                        VStack(alignment: .leading, spacing: 16) {
                            Text("MEETING INTENT")
                                .font(.system(size: 12, weight: .bold))
                                .foregroundColor(AppColors.onSurfaceVariant)
                                .kerning(1.2)
                            
                            VStack(spacing: 20) {
                                HStack(alignment: .top, spacing: 12) {
                                    Image(systemName: "lightbulb")
                                        .font(.system(size: 20))
                                        .foregroundColor(AppColors.secondary)
                                        .padding(10)
                                        .background(AppColors.secondary.opacity(0.15))
                                        .cornerRadius(8)
                                    
                                    VStack(alignment: .leading, spacing: 6) {
                                        Text("Sarah wants to discuss:")
                                            .font(.system(size: 14, weight: .semibold))
                                            .foregroundColor(AppColors.onSurface)
                                        Text("\"Seed-round roadmapping and hiring for early-stage product teams.\"")
                                            .font(.system(size: 14, weight: .regular))
                                            .italic()
                                            .foregroundColor(AppColors.onSurfaceVariant)
                                    }
                                }
                                
                                VStack(alignment: .leading, spacing: 8) {
                                    Text("Add your talking points (optional)")
                                        .font(.system(size: 12, weight: .medium))
                                        .foregroundColor(AppColors.onSurface)
                                    
                                    TextField("e.g. Scaling GTM strategies...", text: $talkingPoints)
                                        .font(.system(size: 14))
                                        .padding()
                                        .background(AppColors.secondary.opacity(0.1))
                                        .cornerRadius(12)
                                }
                            }
                            .padding(16)
                            .background(AppColors.surfaceContainerLowest)
                            .cornerRadius(16)
                        }
                        
                        // Bottom Button Space
                        Spacer().frame(height: 100)
                    }
                    .padding(24)
                }
                
                // Confirm Chat Button Footer
                VStack {
                    Spacer()
                    VStack(spacing: 8) {
                        Button(action: {}) {
                            HStack {
                                Text("Confirm Chat")
                                Image(systemName: "paperplane")
                            }
                            .font(.system(size: 16, weight: .semibold))
                            .foregroundColor(AppColors.onPrimary)
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 16)
                            .background(selectedTime != nil ? AppColors.primary : AppColors.primary.opacity(0.5))
                            .cornerRadius(16)
                        }
                        .disabled(selectedTime == nil)
                        
                        Text("Confirming will send a calendar invite to both your synced emails.")
                            .font(.system(size: 10, weight: .regular))
                            .foregroundColor(AppColors.onSurfaceVariant)
                            .multilineTextAlignment(.center)
                    }
                    .padding(.horizontal, 24)
                    .padding(.top, 16)
                    .padding(.bottom, 24)
                    .background(AppColors.surface)
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
                    Text("Schedule")
                        .font(.system(size: 20, weight: .bold))
                        .foregroundColor(AppColors.onSurface)
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

struct SettingButton: View {
    var title: String
    var icon: String
    var isSelected: Bool
    var action: () -> Void
    
    var body: some View {
        Button(action: action) {
            VStack(spacing: 8) {
                Image(systemName: icon)
                    .font(.system(size: 20))
                Text(title)
                    .font(.system(size: 12, weight: .medium))
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, 16)
            .background(isSelected ? Color(hex: 0xffdb94).opacity(0.7) : AppColors.surfaceContainerLowest)
            .foregroundColor(isSelected ? AppColors.onSurface : AppColors.onSurfaceVariant)
            .cornerRadius(12)
        }
    }
}

struct SchedulingView_Previews: PreviewProvider {
    static var previews: some View {
        SchedulingView()
    }
}

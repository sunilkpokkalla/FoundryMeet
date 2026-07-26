import SwiftUI

struct SchedulingView: View {
    @State private var selectedDate = Date()
    @State private var selectedTime: String? = nil
    
    let timeSlots = ["09:00 AM", "10:30 AM", "01:00 PM", "03:30 PM", "05:00 PM"]
    
    var body: some View {
        NavigationView {
            ZStack {
                AppColors.surface.ignoresSafeArea()
                
                VStack(spacing: 0) {
                    ScrollView {
                        VStack(spacing: 24) {
                            
                            // Date Picker Card
                            VStack(alignment: .leading, spacing: 16) {
                                Text("Select a Day")
                                    .font(.system(size: 18, weight: .semibold))
                                    .foregroundColor(AppColors.onSurface)
                                
                                DatePicker(
                                    "Select a date",
                                    selection: $selectedDate,
                                    displayedComponents: [.date]
                                )
                                .datePickerStyle(GraphicalDatePickerStyle())
                                .accentColor(AppColors.secondary)
                            }
                            .padding(20)
                            .background(AppColors.surfaceContainerLowest)
                            .cornerRadius(16)
                            .shadow(color: Color.black.opacity(0.04), radius: 12, x: 0, y: 4)
                            
                            // Time Slots
                            VStack(alignment: .leading, spacing: 16) {
                                Text("Available Slots")
                                    .font(.system(size: 18, weight: .semibold))
                                    .foregroundColor(AppColors.onSurface)
                                
                                LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible()), GridItem(.flexible())], spacing: 12) {
                                    ForEach(timeSlots, id: \.self) { time in
                                        TimeSlotButton(
                                            time: time,
                                            isSelected: selectedTime == time,
                                            action: { selectedTime = time }
                                        )
                                    }
                                }
                            }
                            .padding(20)
                            .background(AppColors.surfaceContainerLowest)
                            .cornerRadius(16)
                            .shadow(color: Color.black.opacity(0.04), radius: 12, x: 0, y: 4)
                        }
                        .padding(20)
                    }
                    
                    // Bottom Button
                    VStack {
                        Button(action: {}) {
                            Text("Confirm Chat")
                                .font(.system(size: 16, weight: .semibold))
                                .foregroundColor(AppColors.onPrimary)
                                .frame(maxWidth: .infinity)
                                .padding(.vertical, 16)
                                .background(selectedTime != nil ? AppColors.primary : AppColors.primary.opacity(0.5))
                                .cornerRadius(12)
                        }
                        .disabled(selectedTime == nil)
                        .padding(20)
                    }
                    .background(AppColors.surfaceContainerLowest)
                    .shadow(color: Color.black.opacity(0.05), radius: 10, x: 0, y: -4)
                }
            }
            .navigationTitle("Schedule Chat")
        }
    }
}

struct SchedulingView_Previews: PreviewProvider {
    static var previews: some View {
        SchedulingView()
    }
}

struct TimeSlotButton: View {
    var time: String
    var isSelected: Bool
    var action: () -> Void
    
    var body: some View {
        Button(action: action) {
            Text(time)
                .font(.system(size: 14, weight: .medium))
                .padding(.vertical, 12)
                .frame(maxWidth: .infinity)
                .background(isSelected ? AppColors.secondary : AppColors.surfaceContainerHigh)
                .foregroundColor(isSelected ? AppColors.onSecondary : AppColors.onSurfaceVariant)
                .cornerRadius(12)
        }
    }
}

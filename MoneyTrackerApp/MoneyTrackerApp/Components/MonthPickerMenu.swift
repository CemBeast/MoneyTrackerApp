import SwiftUI

struct MonthPickerMenu: View {
    @Binding var selectedMonth: MonthKey?
    let availableMonths: [MonthKey]
    
    var body: some View {
        Menu {
            Button {
                selectedMonth = nil
            } label: {
                HStack {
                    Text("All Months")
                    if selectedMonth == nil {
                        Image(systemName: "checkmark")
                    }
                }
            }
            
            Divider()
            
            ForEach(availableMonths.sorted(by: >), id: \.self) { month in
                Button {
                    selectedMonth = month
                } label: {
                    HStack {
                        Text(month.title)
                        if selectedMonth == month {
                            Image(systemName: "checkmark")
                        }
                    }
                }
            }
        } label: {
            HStack(spacing: 6) {
                Text(selectedMonth?.title ?? "All Months")
                    .font(.caption)
                    .fontWeight(.medium)
                Image(systemName: "chevron.down")
                    .font(.caption2)
            }
            .foregroundColor(.neonGreen)
            .padding(.horizontal, 12)
            .padding(.vertical, 8)
            .background(Color.cyberGray)
            .clipShape(RoundedRectangle(cornerRadius: 8))
            .overlay(
                RoundedRectangle(cornerRadius: 8)
                    .stroke(Color.neonGreen.opacity(0.3), lineWidth: 1)
            )
        }
    }
}

import SwiftUI
import CoreData

struct BudgetsView: View {
    @Environment(\.managedObjectContext) private var viewContext
    @Environment(\.dismiss) private var dismiss
    
    let monthStart: Date
    
    @FetchRequest private var budgets: FetchedResults<CDBudget>
    
    @State private var budgetLimits: [MoneyCategory: String] = [:]
    
    init(monthStart: Date) {
        self.monthStart = monthStart
        
        let startOfMonth = monthStart.startOfMonth()
        let endOfMonth = Calendar.current.date(byAdding: .month, value: 1, to: startOfMonth) ?? startOfMonth
        
        let request = NSFetchRequest<CDBudget>(entityName: "CDBudget")
        request.predicate = NSPredicate(format: "monthStart >= %@ AND monthStart < %@",
                                       startOfMonth as NSDate,
                                       endOfMonth as NSDate)
        request.sortDescriptors = [NSSortDescriptor(keyPath: \CDBudget.categoryRaw, ascending: true)]
        
        _budgets = FetchRequest(fetchRequest: request)
    }
    
    private func categoryColor(_ category: MoneyCategory) -> Color {
        switch category {
        case .housing: return .neonBlue
        case .fixedBills: return .neonRed
        case .food: return .neonOrange
        case .transportation: return .neonPurple
        case .healthcare: return .neonYellow
        case .funLifestyle: return .neonPink
        case .shopping: return .neonBlue
        case .subscriptions: return .neonGreen
        case .savings: return .neonGreen
        case .investing: return .neonPurple
        case .travel: return .neonOrange
        case .gifts: return .neonPink
        case .misc: return .white.opacity(0.7)
        }
    }
    
    var body: some View {
        NavigationView {
            ZStack {
                Color.cyberBlack.ignoresSafeArea()
                
                ScrollView {
                    VStack(spacing: 24) {
                        // Info card
                        HStack(spacing: 12) {
                            Image(systemName: "info.circle.fill")
                                .foregroundColor(.neonGreen)
                            
                            Text("Set monthly budgets for each category. Leave empty to remove.")
                                .font(.caption)
                                .foregroundColor(.white.opacity(0.6))
                        }
                        .padding()
                        .cyberCard()
                        
                        // Budget inputs
                        VStack(spacing: 16) {
                            CyberSectionHeader(title: "Category Budgets")
                            
                            VStack(spacing: 1) {
                                ForEach(MoneyCategory.allCases) { category in
                                    CyberBudgetInputRow(
                                        category: category,
                                        color: categoryColor(category),
                                        value: Binding(
                                            get: { budgetLimits[category] ?? "" },
                                            set: { budgetLimits[category] = $0 }
                                        )
                                    )
                                }
                            }
                            .clipShape(RoundedRectangle(cornerRadius: 12))
                            .overlay(
                                RoundedRectangle(cornerRadius: 12)
                                    .stroke(Color.neonGreen.opacity(0.2), lineWidth: 1)
                            )
                        }
                        
                        // Save button
                        Button {
                            save()
                        } label: {
                            Text("Save Budgets")
                                .font(.headline)
                                .fontWeight(.bold)
                                .foregroundColor(.cyberBlack)
                                .frame(maxWidth: .infinity)
                                .padding(.vertical, 16)
                                .background(Color.neonGreen)
                                .clipShape(RoundedRectangle(cornerRadius: 12))
                                .shadow(color: .neonGreenGlow, radius: 10)
                        }
                    }
                    .padding()
                }
            }
            .cyberNavTitle("Budgets")
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                        .foregroundColor(.neonGreen)
                }
            }
            .onAppear {
                loadBudgets()
            }
        }
    }
    
    private func loadBudgets() {
        for budget in budgets {
            budgetLimits[budget.category] = budget.limit > 0 ? String(budget.limit) : ""
        }
    }
    
    private func save() {
        let startOfMonth = monthStart.startOfMonth()
        
        // Delete existing budgets for this month
        for budget in budgets {
            viewContext.delete(budget)
        }
        
        // Create/update budgets
        for category in MoneyCategory.allCases {
            if let limitText = budgetLimits[category], !limitText.isEmpty,
               let limit = Double(limitText), limit > 0 {
                let budget = CDBudget(context: viewContext)
                budget.id = UUID()
                budget.monthStart = startOfMonth
                budget.categoryRaw = category.rawValue
                budget.limit = limit
            }
        }
        
        PersistenceController.shared.save(viewContext)
        dismiss()
    }
}

struct CyberBudgetInputRow: View {
    let category: MoneyCategory
    let color: Color
    @Binding var value: String
    
    var body: some View {
        HStack(spacing: 12) {
            HStack(spacing: 10) {
                Circle()
                    .fill(color)
                    .frame(width: 10, height: 10)
                
                Text(category.rawValue)
                    .foregroundColor(.white)
            }
            
            Spacer()
            
            HStack(spacing: 4) {
                Text("$")
                    .foregroundColor(.neonGreen.opacity(0.6))
                
                TextField("0.00", text: $value)
                    .keyboardType(.decimalPad)
                    .multilineTextAlignment(.trailing)
                    .foregroundColor(.neonGreen)
                    .frame(width: 80)
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 8)
            .background(Color.cyberGray)
            .clipShape(RoundedRectangle(cornerRadius: 8))
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 14)
        .background(Color.cyberDarkGray)
    }
}

import SwiftUI
import CoreData

// Sentinel date used as the key for global (month-agnostic) budgets.
let globalBudgetDate = Date(timeIntervalSince1970: 0)

struct BudgetsView: View {
    @Environment(\.managedObjectContext) private var viewContext
    @Environment(\.dismiss) private var dismiss
    @EnvironmentObject var currencyViewModel: CurrencyViewModel

    @FetchRequest(
        sortDescriptors: [NSSortDescriptor(keyPath: \CDBudget.categoryRaw, ascending: true)],
        predicate: NSPredicate(format: "monthStart == %@", Date(timeIntervalSince1970: 0) as NSDate)
    )
    private var budgets: FetchedResults<CDBudget>

    @State private var budgetLimits: [MoneyCategory: String] = [:]

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

                            Text("Set a budget for each category. These limits apply to every month.")
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
                                        color: category.color,
                                        currencySymbol: currencyViewModel.selectedCurrency.currencySymbol,
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
            .onChange(of: currencyViewModel.selectedCurrency) { _ in
                loadBudgets()
            }
        }
    }

    private func loadBudgets() {
        for budget in budgets {
            if budget.limit > 0 {
                let converted = currencyViewModel.convertFromBase(budget.limit)
                budgetLimits[budget.category] = String(Int(converted.rounded()))
            } else {
                budgetLimits[budget.category] = ""
            }
        }
    }

    private func save() {
        // Delete all existing global budgets
        for budget in budgets {
            viewContext.delete(budget)
        }

        // Re-create, converting display currency back to base (USD)
        for category in MoneyCategory.allCases {
            if let limitText = budgetLimits[category], !limitText.isEmpty,
               let limitInDisplay = Double(limitText), limitInDisplay > 0 {
                let budget = CDBudget(context: viewContext)
                budget.id = UUID()
                budget.monthStart = globalBudgetDate
                budget.categoryRaw = category.rawValue
                budget.limit = currencyViewModel.convertToBase(limitInDisplay)
            }
        }

        PersistenceController.shared.save(viewContext)
        dismiss()
    }
}

struct CyberBudgetInputRow: View {
    let category: MoneyCategory
    let color: Color
    let currencySymbol: String
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
                Text(currencySymbol)
                    .foregroundColor(.neonGreen.opacity(0.6))

                TextField("0", text: $value)
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

import SwiftUI
import CoreData

struct CategoryDetailView: View {
    @Environment(\.managedObjectContext) private var viewContext
    @EnvironmentObject var currencyViewModel: CurrencyViewModel
    let category: MoneyCategory
    @State private var selectedMonth: MonthKey?
    
    @FetchRequest(sortDescriptors: [NSSortDescriptor(keyPath: \CDTransaction.date, ascending: false)])
    private var allTransactions: FetchedResults<CDTransaction>
    
    private var availableMonths: [MonthKey] {
        let categoryTransactions = allTransactions.filter { $0.category == category }
        let months = Set(categoryTransactions.map { $0.date.monthKey() })
        return Array(months).sorted(by: >)
    }
    
    private var categoryTransactions: [CDTransaction] {
        var filtered = allTransactions.filter { $0.category == category }
        
        if let month = selectedMonth {
            let startDate = month.startDate
            let endDate = Calendar.current.date(byAdding: .month, value: 1, to: startDate) ?? startDate
            filtered = filtered.filter { $0.date >= startDate && $0.date < endDate }
        }
        
        return filtered.sorted { $0.date > $1.date }
    }
    
    private var total: Double {
        categoryTransactions.reduce(0) { $0 + $1.amount }
    }
    
    private var categoryColor: Color {
        category.color
    }
    
    private var categoryIcon: String {
        switch category {
        case .housing: return "house.fill"
        case .fixedBills: return "building.2.fill"
        case .food: return "fork.knife"
        case .transportation: return "car.fill"
        case .healthcare: return "cross.case.fill"
        case .funLifestyle: return "gamecontroller.fill"
        case .shopping: return "bag.fill"
        case .subscriptions: return "repeat"
        case .savings: return "banknote.fill"
        case .investing: return "chart.line.uptrend.xyaxis"
        case .travel: return "airplane"
        case .gifts: return "gift.fill"
        case .misc: return "ellipsis.circle.fill"
        }
    }
    
    var body: some View {
        ZStack {
            Color.cyberBlack.ignoresSafeArea()

            ScrollView {
                VStack(spacing: 16) {
                    // Header card
                    VStack(spacing: 16) {
                        ZStack {
                            RoundedRectangle(cornerRadius: 16)
                                .fill(categoryColor.opacity(0.15))
                                .frame(width: 60, height: 60)

                            Image(systemName: categoryIcon)
                                .font(.system(size: 24))
                                .foregroundColor(categoryColor)
                        }

                        Text(currencyViewModel.format(amountInBase: total))
                            .font(.system(size: 36, weight: .bold, design: .monospaced))
                            .foregroundColor(categoryColor)
                            .shadow(color: categoryColor.opacity(0.5), radius: 8)
                            .id("category-total-\(category.id)-\(total)-\(allTransactions.count)")

                        Text("\(categoryTransactions.count) transactions")
                            .font(.caption)
                            .foregroundColor(.white.opacity(0.4))
                            .id("category-count-\(category.id)-\(categoryTransactions.count)")
                    }
                    .padding(.vertical, 24)
                    .frame(maxWidth: .infinity)
                    .cyberCard(glowColor: categoryColor)

                    // Transaction list
                    LazyVStack(spacing: 8) {
                        ForEach(categoryTransactions) { transaction in
                            NavigationLink(destination: AddEditTransactionView(transaction: transaction)) {
                                CyberTransactionRow(transaction: transaction, currencyViewModel: currencyViewModel)
                                    .id("\(transaction.id)-\(transaction.categoryRaw)-\(transaction.amount)-\(transaction.date.timeIntervalSince1970)-\(transaction.notes ?? "")")
                            }
                            .buttonStyle(.plain)
                        }
                        .id("category-transactions-\(category.id)-\(allTransactions.count)")

                        if categoryTransactions.isEmpty {
                            VStack(spacing: 12) {
                                Image(systemName: categoryIcon)
                                    .font(.system(size: 32))
                                    .foregroundColor(categoryColor.opacity(0.3))

                                Text("No transactions")
                                    .font(.subheadline)
                                    .foregroundColor(.white.opacity(0.4))
                            }
                            .padding(.top, 40)
                        }
                    }
                }
                .padding()
            }
        }
        .cyberNavTitle(category.rawValue)
        .toolbar {
            ToolbarItem(placement: .navigationBarTrailing) {
                Menu {
                    Button("All Time") {
                        selectedMonth = nil
                    }
                    ForEach(availableMonths, id: \.self) { month in
                        Button(month.title) {
                            selectedMonth = month
                        }
                    }
                } label: {
                    HStack(spacing: 4) {
                        Text(selectedMonth?.title ?? "All Time")
                            .font(.caption)
                        Image(systemName: "chevron.down")
                            .font(.caption2)
                    }
                    .foregroundColor(.neonGreen)
                }
            }
        }
    }
}

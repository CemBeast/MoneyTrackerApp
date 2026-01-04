import SwiftUI
import CoreData

struct CategoryDetailView: View {
    @Environment(\.managedObjectContext) private var viewContext
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
            
            VStack(spacing: 0) {
                // Header
                VStack(spacing: 16) {
                    ZStack {
                        Circle()
                            .fill(categoryColor.opacity(0.15))
                            .frame(width: 60, height: 60)
                        
                        Image(systemName: categoryIcon)
                            .font(.system(size: 24))
                            .foregroundColor(categoryColor)
                    }
                    
                    Text(total.currency())
                        .font(.system(size: 36, weight: .bold, design: .monospaced))
                        .foregroundColor(categoryColor)
                        .shadow(color: categoryColor.opacity(0.5), radius: 8)
                        .id("category-total-\(category.id)-\(total)-\(allTransactions.count)")
                    
                    Text("\(categoryTransactions.count) transactions")
                        .font(.caption)
                        .foregroundColor(.white.opacity(0.4))
                        .id("category-count-\(category.id)-\(categoryTransactions.count)")
                    
                    // Month filter
                    if !availableMonths.isEmpty {
                        ScrollView(.horizontal, showsIndicators: false) {
                            HStack(spacing: 8) {
                                CyberFilterPill(
                                    title: "All Time",
                                    isSelected: selectedMonth == nil
                                ) {
                                    selectedMonth = nil
                                }
                                
                                ForEach(availableMonths.prefix(6), id: \.self) { month in
                                    CyberFilterPill(
                                        title: month.title,
                                        isSelected: selectedMonth == month
                                    ) {
                                        selectedMonth = month
                                    }
                                }
                            }
                            .padding(.horizontal)
                        }
                    }
                }
                .padding(.vertical, 24)
                .frame(maxWidth: .infinity)
                .background(Color.cyberDarkGray)
                
                // Transaction list
                ScrollView {
                    LazyVStack(spacing: 8) {
                        ForEach(categoryTransactions) { transaction in
                            NavigationLink(destination: AddEditTransactionView(transaction: transaction)) {
                                CyberTransactionRow(transaction: transaction)
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
                    .padding()
                }
            }
        }
        .cyberNavTitle(category.rawValue)
    }
}

struct CyberFilterPill: View {
    let title: String
    let isSelected: Bool
    let action: () -> Void
    
    var body: some View {
        Button(action: action) {
            Text(title)
                .font(.caption)
                .fontWeight(.medium)
                .foregroundColor(isSelected ? .cyberBlack : .neonGreen)
                .padding(.horizontal, 14)
                .padding(.vertical, 8)
                .background(isSelected ? Color.neonGreen : Color.cyberGray)
                .clipShape(Capsule())
                .overlay(
                    Capsule()
                        .stroke(Color.neonGreen.opacity(isSelected ? 0 : 0.5), lineWidth: 1)
                )
        }
    }
}

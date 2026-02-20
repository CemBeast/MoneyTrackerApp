import SwiftUI
import CoreData

struct MonthsView: View {
    @Environment(\.managedObjectContext) private var viewContext
    @State private var selectedMonth: MonthKey?
    @State private var refreshToken = UUID()
    
    @FetchRequest(sortDescriptors: [NSSortDescriptor(keyPath: \CDTransaction.date, ascending: false)])
    private var allTransactions: FetchedResults<CDTransaction>
    
    // Signature to detect any change in transactions (add/edit/delete/date/category/amount)
    private var transactionSignature: String {
        allTransactions.map {
            "\($0.id.uuidString)-\($0.amount)-\($0.date.timeIntervalSince1970)-\($0.categoryRaw)-\($0.paymentMethodRaw ?? "")-\($0.notes ?? "")"
        }.joined(separator: "|")
    }
    
    private var availableMonths: [MonthKey] {
        let months = Set(allTransactions.map { $0.date.monthKey() })
        return Array(months).sorted(by: >)
    }
    
    var body: some View {
        NavigationView {
            ZStack {
                Color.cyberBlack.ignoresSafeArea()
                
                ScrollView {
                    LazyVStack(spacing: 12) {
                        ForEach(availableMonths, id: \.self) { month in
                            NavigationLink(destination: MonthDetailView(month: month)) {
                                CyberMonthRow(month: month, transactions: allTransactions)
                                    .id("\(month.year)-\(month.month)-\(transactionSignature)")
                            }
                        }
                        .id("months-list-\(refreshToken)")
                        
                        if availableMonths.isEmpty {
                            VStack(spacing: 16) {
                                Image(systemName: "calendar.badge.plus")
                                    .font(.system(size: 48))
                                    .foregroundColor(.neonGreen.opacity(0.3))
                                
                                Text("No transactions yet")
                                    .font(.headline)
                                    .foregroundColor(.white.opacity(0.5))
                                
                                Text("Add transactions to see monthly summaries")
                                    .font(.caption)
                                    .foregroundColor(.white.opacity(0.3))
                            }
                            .padding(.top, 60)
                        }
                    }
                    .padding()
                }
            }
            .onChange(of: transactionSignature) { _ in
                refreshToken = UUID()
            }
        }
    }
}

struct CyberMonthRow: View {
    let month: MonthKey
    let transactions: FetchedResults<CDTransaction>
    
    private var monthTransactions: [CDTransaction] {
        let startDate = month.startDate
        let endDate = Calendar.current.date(byAdding: .month, value: 1, to: startDate) ?? startDate
        return transactions.filter { $0.date >= startDate && $0.date < endDate }
    }
    
    private var total: Double {
        let startDate = month.startDate
        let endDate = Calendar.current.date(byAdding: .month, value: 1, to: startDate) ?? startDate
        return transactions
            .filter { $0.date >= startDate && $0.date < endDate && $0.type == .expense }
            .reduce(0) { $0 + $1.amount }
    }
    
    private var transactionCount: Int {
        let startDate = month.startDate
        let endDate = Calendar.current.date(byAdding: .month, value: 1, to: startDate) ?? startDate
        return transactions.filter { $0.date >= startDate && $0.date < endDate }.count
    }
    
    var body: some View {
        HStack(spacing: 16) {
            // Month icon
            ZStack {
                RoundedRectangle(cornerRadius: 12)
                    .fill(Color.neonGreen.opacity(0.15))
                    .frame(width: 50, height: 50)
                
                VStack(spacing: 0) {
                    Text(monthAbbrev)
                        .font(.caption2)
                        .fontWeight(.bold)
                        .foregroundColor(.neonGreen)
                    Text(yearShort)
                        .font(.headline)
                        .fontWeight(.bold)
                        .foregroundColor(.neonGreen)
                }
            }
            
            VStack(alignment: .leading, spacing: 4) {
                Text(month.title)
                    .font(.headline)
                    .foregroundColor(.white)
                
                Text("\(transactionCount) transactions")
                    .font(.caption)
                    .foregroundColor(.white.opacity(0.5))
            }
            
            Spacer()
            
            VStack(alignment: .trailing, spacing: 4) {
                Text(total.currency())
                    .font(.title3)
                    .fontWeight(.bold)
                    .foregroundColor(.neonGreen)
                
                Image(systemName: "chevron.right")
                    .font(.caption)
                    .foregroundColor(.neonGreen.opacity(0.5))
            }
        }
        .padding(16)
        .background(Color.cyberDarkGray)
        .clipShape(RoundedRectangle(cornerRadius: 14))
        .overlay(
            RoundedRectangle(cornerRadius: 14)
                .stroke(Color.neonGreen.opacity(0.2), lineWidth: 1)
        )
    }
    
    private var monthAbbrev: String {
        let formatter = DateFormatter()
        formatter.dateFormat = "MMM"
        return formatter.string(from: month.startDate).uppercased()
    }
    
    private var yearShort: String {
        let formatter = DateFormatter()
        formatter.dateFormat = "yy"
        return formatter.string(from: month.startDate)
    }
}

struct MonthDetailView: View {
    @Environment(\.managedObjectContext) private var viewContext
    let month: MonthKey
    @State private var showBudgets = false
    
    @FetchRequest(sortDescriptors: [NSSortDescriptor(keyPath: \CDTransaction.date, ascending: false)])
    private var allTransactions: FetchedResults<CDTransaction>
    
    @FetchRequest private var budgets: FetchedResults<CDBudget>
    
    init(month: MonthKey) {
        self.month = month
        
        let startDate = month.startDate
        let endDate = Calendar.current.date(byAdding: .month, value: 1, to: startDate) ?? startDate
        
        let request = NSFetchRequest<CDBudget>(entityName: "CDBudget")
        request.predicate = NSPredicate(format: "monthStart >= %@ AND monthStart < %@",
                                       startDate as NSDate,
                                       endDate as NSDate)
        request.sortDescriptors = [NSSortDescriptor(keyPath: \CDBudget.categoryRaw, ascending: true)]
        _budgets = FetchRequest(fetchRequest: request)
    }
    
    private var monthTransactions: [CDTransaction] {
        let startDate = month.startDate
        let endDate = Calendar.current.date(byAdding: .month, value: 1, to: startDate) ?? startDate
        return allTransactions.filter { $0.date >= startDate && $0.date < endDate }
            .sorted { $0.date > $1.date }
    }
    
    private var totalSpent: Double {
        let startDate = month.startDate
        let endDate = Calendar.current.date(byAdding: .month, value: 1, to: startDate) ?? startDate
        return allTransactions
            .filter { $0.date >= startDate && $0.date < endDate && $0.type == .expense }
            .reduce(0) { $0 + $1.amount }
    }
    
    private var categoryTotals: [MoneyCategory: Double] {
        let startDate = month.startDate
        let endDate = Calendar.current.date(byAdding: .month, value: 1, to: startDate) ?? startDate
        var totals: [MoneyCategory: Double] = [:]
        for transaction in allTransactions where 
            transaction.date >= startDate && 
            transaction.date < endDate && 
            transaction.type == .expense {
            let category = transaction.category
            totals[category, default: 0] += transaction.amount
        }
        return totals
    }
    
    private var budgetMap: [MoneyCategory: Double] {
        var map: [MoneyCategory: Double] = [:]
        for budget in budgets {
            map[budget.category] = budget.limit
        }
        return map
    }
    
    var body: some View {
        ZStack {
            Color.cyberBlack.ignoresSafeArea()
            
            ScrollView {
                VStack(spacing: 20) {
                    // Summary Card
                    VStack(spacing: 12) {
                        Text("TOTAL SPENT")
                            .font(.caption)
                            .fontWeight(.semibold)
                            .foregroundColor(.white.opacity(0.5))
                            .tracking(2)
                        
                        Text(totalSpent.currency())
                            .font(.system(size: 42, weight: .bold, design: .monospaced))
                            .foregroundColor(.neonGreen)
                            .shadow(color: .neonGreenGlow, radius: 10)
                            .id("total-\(allTransactions.count)-\(totalSpent)")
                        
                        Text("\(monthTransactions.count) transactions")
                            .font(.caption)
                            .foregroundColor(.white.opacity(0.4))
                    }
                    .padding(.vertical, 24)
                    .frame(maxWidth: .infinity)
                    .cyberCard()
                    .id("summary-\(allTransactions.count)")
                    
                    // Category Breakdown
                    VStack(spacing: 16) {
                        CyberSectionHeader(title: "By Category")
                        
                        VStack(spacing: 12) {
                            ForEach(MoneyCategory.allCases) { category in
                                if let spent = categoryTotals[category], spent > 0 {
                                    CyberCategoryBudgetRow(
                                        category: category,
                                        spent: spent,
                                        budget: budgetMap[category]
                                    )
                                }
                            }
                        }
                        .padding()
                        .cyberCard()
                    }
                    
                    // Transactions List
                    VStack(spacing: 16) {
                        CyberSectionHeader(title: "Transactions")
                        
                        VStack(spacing: 8) {
                            ForEach(monthTransactions) { transaction in
                                NavigationLink(destination: AddEditTransactionView(transaction: transaction)) {
                                    CyberTransactionRow(transaction: transaction)
                                }
                                .buttonStyle(.plain)
                            }
                        }
                    }
                }
                .padding()
            }
        }
        .cyberNavTitle(month.title)
        .toolbar {
            ToolbarItem(placement: .navigationBarTrailing) {
                HStack(spacing: 12) {
                    Button {
                        let engine = RecurringEngine(context: viewContext)
                        engine.generateForMonth(month)
                    } label: {
                        Image(systemName: "repeat")
                            .foregroundColor(.neonGreen)
                    }
                    
                    Button {
                        showBudgets = true
                    } label: {
                        Image(systemName: "dollarsign.circle")
                            .foregroundColor(.neonGreen)
                    }
                }
            }
        }
        .sheet(isPresented: $showBudgets) {
            BudgetsView(monthStart: month.startDate)
        }
    }
}

struct CyberCategoryBudgetRow: View {
    let category: MoneyCategory
    let spent: Double
    let budget: Double?
    
    private var categoryColor: Color {
        category.color
    }
    
    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                HStack(spacing: 8) {
                    Circle()
                        .fill(categoryColor)
                        .frame(width: 10, height: 10)
                    Text(category.rawValue)
                        .foregroundColor(.white)
                }
                
                Spacer()
                
                Text(spent.currency())
                    .fontWeight(.bold)
                    .foregroundColor(categoryColor)
            }
            
            if let budget = budget, budget > 0 {
                let progress = spent / budget
                let isOver = spent > budget
                
                CyberProgressBar(
                    progress: progress,
                    barColor: categoryColor,
                    isOverBudget: isOver
                )
                
                HStack {
                    Text(isOver ? "Over budget!" : "\((budget - spent).currency()) remaining")
                        .font(.caption2)
                        .foregroundColor(isOver ? .neonRed : .white.opacity(0.4))
                    
                    Spacer()
                    
                    Text("of \(budget.currency())")
                        .font(.caption2)
                        .foregroundColor(.white.opacity(0.4))
                }
            }
        }
    }
}

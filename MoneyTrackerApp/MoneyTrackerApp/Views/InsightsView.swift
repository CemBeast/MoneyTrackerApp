import SwiftUI
import Charts
import CoreData

struct InsightsView: View {
    @Environment(\.managedObjectContext) private var viewContext
    @State private var selectedMonth: MonthKey?
    
    @FetchRequest(
        sortDescriptors: [NSSortDescriptor(keyPath: \CDTransaction.date, ascending: false)]
    )
    private var allTransactions: FetchedResults<CDTransaction>
    
    private var availableMonths: [MonthKey] {
        let months = Set(allTransactions.map { $0.date.monthKey() })
        return Array(months).sorted(by: >)
    }
    
    // Used to force UI refresh when any transaction field changes
    private var transactionSignature: String {
        allTransactions.map {
            "\($0.id.uuidString)-\($0.amount)-\($0.categoryRaw)-\($0.paymentMethodRaw ?? "")-\($0.date.timeIntervalSince1970)-\($0.notes ?? "")"
        }.joined(separator: "|")
    }
    
    private var stats: InsightsStats {
        InsightsStats(context: viewContext)
    }
    
    var body: some View {
        NavigationView {
            ZStack {
                Color.cyberBlack.ignoresSafeArea()
                
                ScrollView {
                    VStack(spacing: 24) {
                        // Overall average
                        CyberStatCard(
                            title: "Average Monthly Spending",
                            value: stats.averagePerMonthOverall().currency()
                        )
                    .id("avg-\(transactionSignature)")
                        
                        // Category averages
                    CyberCategoryAveragesView(stats: stats, transactionSignature: transactionSignature)
                        
                        // Percentages
                    CyberPercentagesView(stats: stats, selectedMonth: selectedMonth, transactionSignature: transactionSignature)
                        
                        // Charts
                    CyberChartsView(stats: stats, availableMonths: availableMonths, selectedMonth: selectedMonth, transactionSignature: transactionSignature)
                    }
                    .padding()
                }
            }
            .cyberNavTitle("Insights")
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
}

struct CyberStatCard: View {
    let title: String
    let value: String
    var valueColor: Color = .neonGreen
    
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text(title)
                .font(.caption)
                .fontWeight(.semibold)
                .foregroundColor(.white.opacity(0.5))
                .textCase(.uppercase)
                .tracking(1)
            
            Text(value)
                .font(.system(size: 32, weight: .bold, design: .monospaced))
                .foregroundColor(valueColor)
                .shadow(color: valueColor.opacity(0.5), radius: 6)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding()
        .cyberCard(glowColor: valueColor)
    }
}

struct CyberCategoryAveragesView: View {
    let stats: InsightsStats
    let transactionSignature: String
    
    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            CyberSectionHeader(title: "Monthly Averages")
            
            let averages = stats.averagePerMonthPerCategory()
            
            VStack(spacing: 12) {
                ForEach(MoneyCategory.allCases) { category in
                    if let avg = averages[category], avg > 0 {
                        HStack {
                            HStack(spacing: 8) {
                                Circle()
                                    .fill(category.color)
                                    .frame(width: 8, height: 8)
                                Text(category.rawValue)
                                    .foregroundColor(.white.opacity(0.8))
                            }
                            Spacer()
                            Text(avg.currency())
                                .font(.subheadline)
                                .fontWeight(.bold)
                                .foregroundColor(category.color)
                        }
                    }
                }
            }
            .padding()
            .cyberCard()
        }
        .id("category-avg-\(transactionSignature)")
    }
}

struct CyberPercentagesView: View {
    let stats: InsightsStats
    let selectedMonth: MonthKey?
    let transactionSignature: String
    
    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            CyberSectionHeader(title: selectedMonth == nil ? "Spending Distribution" : "Distribution (\(selectedMonth!.title))")
            
            let percents = selectedMonth == nil
                ? stats.percentPerCategoryOverall()
                : stats.percentPerCategoryForMonth(selectedMonth!)
            
            VStack(spacing: 14) {
                ForEach(MoneyCategory.allCases) { category in
                    if let percent = percents[category], percent > 0 {
                        VStack(alignment: .leading, spacing: 6) {
                            HStack {
                                HStack(spacing: 8) {
                                    Circle()
                                        .fill(category.color)
                                        .frame(width: 8, height: 8)
                                    Text(category.rawValue)
                                        .font(.caption)
                                        .foregroundColor(.white.opacity(0.8))
                                }
                                Spacer()
                                Text(String(format: "%.1f%%", percent))
                                    .font(.caption)
                                    .fontWeight(.bold)
                                    .foregroundColor(category.color)
                            }
                            
                            CyberProgressBar(
                                progress: percent / 100,
                                barColor: category.color
                            )
                        }
                    }
                }
            }
            .padding()
            .cyberCard()
        }
        .id("percentages-\(transactionSignature)-\(selectedMonth?.title ?? "all")")
    }
}

struct CyberChartsView: View {
    let stats: InsightsStats
    let availableMonths: [MonthKey]
    let selectedMonth: MonthKey?
    let transactionSignature: String
    
    var body: some View {
        VStack(spacing: 24) {
            // Last 6 months bar chart
            CyberLast6MonthsChart(stats: stats, availableMonths: availableMonths)
                .id("last6-\(transactionSignature)")
            
            // Category pie chart
            CyberCategoryPieChart(stats: stats, selectedMonth: selectedMonth, transactionSignature: transactionSignature)
                .id("pie-category-\(transactionSignature)-\(selectedMonth?.title ?? "all")")
            
            // Payment method pie chart
            CyberPaymentMethodPieChart(stats: stats, selectedMonth: selectedMonth, transactionSignature: transactionSignature)
                .id("pie-payment-\(transactionSignature)-\(selectedMonth?.title ?? "all")")
        }
        .id("charts-\(transactionSignature)-\(selectedMonth?.title ?? "all")")
    }
}

struct CyberLast6MonthsChart: View {
    let stats: InsightsStats
    let availableMonths: [MonthKey]
    
    private var last6Months: [MonthKey] {
        Array(availableMonths.sorted(by: >).prefix(6)).sorted(by: <)
    }
    
    private var chartData: [(month: String, total: Double)] {
        let monthly = stats.monthlyTotals()
        return last6Months.map { month in
            let formatter = DateFormatter()
            formatter.dateFormat = "MMM"
            let shortMonth = formatter.string(from: month.startDate)
            return (month: shortMonth, total: monthly[month] ?? 0)
        }
    }
    
    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            CyberSectionHeader(title: "Last 6 Months")
            
            VStack(alignment: .leading, spacing: 12) {
                if #available(iOS 16.0, *) {
                    Chart {
                        ForEach(Array(chartData.enumerated()), id: \.offset) { index, data in
                            BarMark(
                                x: .value("Month", data.month),
                                y: .value("Amount", data.total)
                            )
                            .foregroundStyle(
                                LinearGradient(
                                    colors: [.neonGreen, .neonGreen.opacity(0.5)],
                                    startPoint: .top,
                                    endPoint: .bottom
                                )
                            )
                            .cornerRadius(4)
                        }
                    }
                    .chartXAxis {
                        AxisMarks { _ in
                            AxisValueLabel()
                                .foregroundStyle(Color.white.opacity(0.6))
                        }
                    }
                    .chartYAxis {
                        AxisMarks { _ in
                            AxisGridLine()
                                .foregroundStyle(Color.white.opacity(0.1))
                            AxisValueLabel()
                                .foregroundStyle(Color.white.opacity(0.4))
                        }
                    }
                    .frame(height: 200)
                } else {
                    Text("Charts require iOS 16+")
                        .foregroundColor(.white.opacity(0.4))
                }
            }
            .padding()
            .cyberCard()
        }
    }
}

struct CyberCategoryPieChart: View {
    let stats: InsightsStats
    let selectedMonth: MonthKey?
    let transactionSignature: String
    
    private var chartData: [(category: String, amount: Double, percent: Double, color: Color)] {
        let percents: [MoneyCategory: Double]
        let amounts: [MoneyCategory: Double]
        
        if let month = selectedMonth {
            percents = stats.percentPerCategoryForMonth(month)
            // Get amounts for the selected month
            let startDate = month.startDate
            let endDate = Calendar.current.date(byAdding: .month, value: 1, to: startDate) ?? startDate
            let request = NSFetchRequest<CDTransaction>(entityName: "CDTransaction")
            request.predicate = NSPredicate(format: "date >= %@ AND date < %@ AND typeRaw == %d",
                                           startDate as NSDate,
                                           endDate as NSDate,
                                           TransactionType.expense.rawValue)
            
            if let transactions = try? stats.context.fetch(request) {
                var totals: [MoneyCategory: Double] = [:]
                for transaction in transactions {
                    totals[transaction.category, default: 0] += transaction.amount
                }
                amounts = totals
            } else {
                amounts = [:]
            }
        } else {
            amounts = stats.allTimeTotalsPerCategory()
            let grandTotal = amounts.values.reduce(0, +)
            guard grandTotal > 0 else { return [] }
            percents = amounts.mapValues { ($0 / grandTotal) * 100 }
        }
        
        guard !percents.isEmpty else { return [] }
        
        return percents.compactMap { category, percent in
            guard percent > 0 else { return nil }
            let color = category.color
            return (
                category: category.rawValue,
                amount: amounts[category] ?? 0,
                percent: percent,
                color: color
            )
        }.sorted { $0.amount > $1.amount }
    }
    
    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            CyberSectionHeader(title: selectedMonth == nil ? "Category Distribution" : "Distribution (\(selectedMonth!.title))")
            
            VStack(spacing: 16) {
                if #available(iOS 16.0, *) {
                    Chart {
                        ForEach(Array(chartData.enumerated()), id: \.offset) { index, data in
                            SectorMark(
                                angle: .value("Percent", data.percent),
                                innerRadius: .ratio(0.55),
                                angularInset: 2
                            )
                            .foregroundStyle(data.color)
                            .annotation(position: .overlay) {
                                if data.percent > 8 {
                                    Text(String(format: "%.0f%%", data.percent))
                                        .font(.caption2)
                                        .fontWeight(.bold)
                                        .foregroundColor(.white)
                                }
                            }
                        }
                    }
                    .frame(height: 220)
                    
                    // Legend
                    LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: 10) {
                        ForEach(Array(chartData.enumerated()), id: \.offset) { index, data in
                            HStack(spacing: 8) {
                                Circle()
                                    .fill(data.color)
                                    .frame(width: 10, height: 10)
                                
                                Text(data.category)
                                    .font(.caption)
                                    .foregroundColor(.white.opacity(0.7))
                                    .lineLimit(1)
                                
                                Spacer()
                                
                                Text(String(format: "%.1f%%", data.percent))
                                    .font(.caption)
                                    .fontWeight(.medium)
                                    .foregroundColor(data.color)
                            }
                        }
                    }
                } else {
                    Text("Charts require iOS 16+")
                        .foregroundColor(.white.opacity(0.4))
                }
            }
            .padding()
            .cyberCard()
            .id("category-chart-\(transactionSignature)-\(selectedMonth?.title ?? "all")")
        }
    }
}
    
struct CyberPaymentMethodPieChart: View {
    let stats: InsightsStats
    let selectedMonth: MonthKey?
    let transactionSignature: String
    
    private var chartData: [(method: String, amount: Double, percent: Double, color: Color)] {
        let percents: [PaymentMethod: Double]
        let amounts: [PaymentMethod: Double]
        
        if let month = selectedMonth {
            percents = stats.percentPerPaymentMethodForMonth(month)
            // Get amounts for the selected month
            let startDate = month.startDate
            let endDate = Calendar.current.date(byAdding: .month, value: 1, to: startDate) ?? startDate
            let request = NSFetchRequest<CDTransaction>(entityName: "CDTransaction")
            request.predicate = NSPredicate(format: "date >= %@ AND date < %@ AND typeRaw == %d",
                                           startDate as NSDate,
                                           endDate as NSDate,
                                           TransactionType.expense.rawValue)
            
            if let transactions = try? stats.context.fetch(request) {
                var totals: [PaymentMethod: Double] = [:]
                for transaction in transactions {
                    totals[transaction.paymentMethod, default: 0] += transaction.amount
                }
                amounts = totals
            } else {
                amounts = [:]
            }
        } else {
            amounts = stats.allTimeTotalsPerPaymentMethod()
            let grandTotal = amounts.values.reduce(0, +)
            guard grandTotal > 0 else { return [] }
            percents = amounts.mapValues { ($0 / grandTotal) * 100 }
        }
        
        guard !percents.isEmpty else { return [] }
        
        return percents.compactMap { method, percent in
            guard percent > 0 else { return nil }
            let color = paymentMethodColor(method)
            return (
                method: method.rawValue,
                amount: amounts[method] ?? 0,
                percent: percent,
                color: color
            )
        }.sorted { $0.amount > $1.amount }
    }
    
    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            CyberSectionHeader(title: selectedMonth == nil ? "Payment Method Distribution" : "Payment Methods (\(selectedMonth!.title))")
            
            VStack(spacing: 16) {
                if #available(iOS 16.0, *) {
                    Chart {
                        ForEach(Array(chartData.enumerated()), id: \.offset) { index, data in
                            SectorMark(
                                angle: .value("Percent", data.percent),
                                innerRadius: .ratio(0.55),
                                angularInset: 2
                            )
                            .foregroundStyle(data.color)
                            .annotation(position: .overlay) {
                                if data.percent > 8 {
                                    Text(String(format: "%.0f%%", data.percent))
                                        .font(.caption2)
                                        .fontWeight(.bold)
                                        .foregroundColor(.white)
                                }
                            }
                        }
                    }
                    .frame(height: 220)
                    
                    // Legend
                    LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: 10) {
                        ForEach(Array(chartData.enumerated()), id: \.offset) { index, data in
                            HStack(spacing: 8) {
                                Circle()
                                    .fill(data.color)
                                    .frame(width: 10, height: 10)
                                
                                Text(data.method)
                                    .font(.caption)
                                    .foregroundColor(.white.opacity(0.7))
                                    .lineLimit(1)
                                
                                Spacer()
                                
                                Text(String(format: "%.1f%%", data.percent))
                                    .font(.caption)
                                    .fontWeight(.medium)
                                    .foregroundColor(data.color)
                            }
                        }
                    }
                } else {
                    Text("Charts require iOS 16+")
                        .foregroundColor(.white.opacity(0.4))
                }
            }
            .padding()
            .cyberCard()
            .id("payment-chart-\(transactionSignature)-\(selectedMonth?.title ?? "all")")
        }
    }
    
    private func paymentMethodColor(_ method: PaymentMethod) -> Color {
        switch method {
        case .cash: return .neonGreen
        case .debit: return .neonBlue
        case .credit: return .neonPink
        case .applePay: return .neonPurple
        case .venmo: return .neonOrange
        case .other: return .white.opacity(0.7)
        }
    }
}

import SwiftUI
import Charts
import CoreData

struct InsightsView: View {
    @Environment(\.managedObjectContext) private var viewContext
    @EnvironmentObject var currencyViewModel: CurrencyViewModel
    @State private var selectedMonth: MonthKey?
    @State private var rangeStart: Date?
    @State private var rangeEnd: Date?
    @State private var showRangePicker = false

    @FetchRequest(
        sortDescriptors: [NSSortDescriptor(keyPath: \CDTransaction.date, ascending: false)]
    )
    private var allTransactions: FetchedResults<CDTransaction>

    private var availableMonths: [MonthKey] {
        let months = Set(allTransactions.map { $0.date.monthKey() })
        return Array(months).sorted(by: >)
    }

    private var transactionSignature: String {
        allTransactions.map {
            "\($0.id.uuidString)-\($0.amount)-\($0.categoryRaw)-\($0.paymentMethodRaw ?? "")-\($0.date.timeIntervalSince1970)-\($0.notes ?? "")"
        }.joined(separator: "|")
    }

    private var stats: InsightsStats {
        InsightsStats(context: viewContext)
    }

    private var rangeStatTitle: String {
        guard let start = rangeStart else { return "Average Monthly Spending" }
        let f = DateFormatter(); f.dateFormat = "MMM d"
        if let end = rangeEnd { return "Total Spent (\(f.string(from: start)) – \(f.string(from: end)))" }
        return "Total Spent (From \(f.string(from: start)))"
    }

    private var rangeStatValue: Double {
        guard let start = rangeStart else { return stats.averagePerMonthOverall() }
        let startOfDay = Calendar.current.startOfDay(for: start)
        let endOfDay: Date = rangeEnd.map {
            Calendar.current.date(byAdding: .day, value: 1, to: Calendar.current.startOfDay(for: $0)) ?? $0
        } ?? Date.distantFuture
        let request = NSFetchRequest<CDTransaction>(entityName: "CDTransaction")
        request.predicate = NSPredicate(
            format: "date >= %@ AND date < %@ AND typeRaw == %d",
            startOfDay as NSDate, endOfDay as NSDate, TransactionType.expense.rawValue
        )
        return ((try? viewContext.fetch(request)) ?? []).reduce(0.0) { $0 + $1.amount }
    }

    private var rangeLabel: String {
        guard let start = rangeStart else { return "Range" }
        let f = DateFormatter(); f.dateFormat = "MMM d"
        if let end = rangeEnd { return "\(f.string(from: start)) – \(f.string(from: end))" }
        return "From \(f.string(from: start))"
    }

    var body: some View {
        NavigationView {
            ZStack {
                Color.cyberBlack.ignoresSafeArea()

                ScrollView {
                    VStack(spacing: 24) {
                        CyberStatCard(
                            title: rangeStatTitle,
                            value: currencyViewModel.format(amountInBase: rangeStatValue)
                        )
                        .id("stat-\(transactionSignature)-\(rangeStart?.timeIntervalSince1970 ?? 0)")

                        CyberCategoryAveragesView(
                            stats: stats,
                            rangeStart: rangeStart,
                            rangeEnd: rangeEnd,
                            transactionSignature: transactionSignature
                        )

                        CyberPercentagesView(
                            stats: stats,
                            selectedMonth: rangeStart == nil ? selectedMonth : nil,
                            rangeStart: rangeStart,
                            rangeEnd: rangeEnd,
                            transactionSignature: transactionSignature
                        )

                        CyberChartsView(
                            stats: stats,
                            availableMonths: availableMonths,
                            selectedMonth: rangeStart == nil ? selectedMonth : nil,
                            rangeStart: rangeStart,
                            rangeEnd: rangeEnd,
                            transactionSignature: transactionSignature
                        )
                    }
                    .padding()
                }
            }
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    HStack(spacing: 12) {
                        // Range picker button
                        Button {
                            showRangePicker = true
                        } label: {
                            HStack(spacing: 4) {
                                Text(rangeLabel)
                                    .font(.caption)
                                Image(systemName: "calendar")
                                    .font(.caption2)
                            }
                            .foregroundColor(rangeStart != nil ? .neonGreen : .neonGreen.opacity(0.6))
                        }

                        // Month menu (disabled when range is active)
                        if rangeStart == nil {
                            Menu {
                                Button("All Time") { selectedMonth = nil }
                                ForEach(availableMonths, id: \.self) { month in
                                    Button(month.title) { selectedMonth = month }
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
            .sheet(isPresented: $showRangePicker) {
                CyberRangePickerSheet(startDate: $rangeStart, endDate: $rangeEnd)
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
    @EnvironmentObject var currencyViewModel: CurrencyViewModel
    let stats: InsightsStats
    let rangeStart: Date?
    let rangeEnd: Date?
    let transactionSignature: String

    private var rangeTotals: [MoneyCategory: Double]? {
        guard let start = rangeStart else { return nil }
        let startOfDay = Calendar.current.startOfDay(for: start)
        let endOfDay: Date
        if let end = rangeEnd {
            endOfDay = Calendar.current.date(byAdding: .day, value: 1, to: Calendar.current.startOfDay(for: end)) ?? end
        } else {
            endOfDay = Date.distantFuture
        }
        let request = NSFetchRequest<CDTransaction>(entityName: "CDTransaction")
        request.predicate = NSPredicate(
            format: "date >= %@ AND date < %@ AND typeRaw == %d",
            startOfDay as NSDate, endOfDay as NSDate, TransactionType.expense.rawValue
        )
        guard let txns = try? stats.context.fetch(request) else { return nil }
        var totals: [MoneyCategory: Double] = [:]
        for t in txns { totals[t.category, default: 0] += t.amount }
        return totals
    }

    private var sectionTitle: String {
        guard let start = rangeStart else { return "Monthly Averages" }
        let f = DateFormatter(); f.dateFormat = "MMM d"
        if let end = rangeEnd { return "Spending (\(f.string(from: start)) – \(f.string(from: end)))" }
        return "Spending (From \(f.string(from: start)))"
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            CyberSectionHeader(title: sectionTitle)

            let values: [MoneyCategory: Double] = rangeTotals ?? stats.averagePerMonthPerCategory()

            VStack(spacing: 12) {
                ForEach(MoneyCategory.allCases) { category in
                    if let val = values[category], val > 0 {
                        HStack {
                            HStack(spacing: 8) {
                                Circle()
                                    .fill(category.color)
                                    .frame(width: 8, height: 8)
                                Text(category.rawValue)
                                    .foregroundColor(.white.opacity(0.8))
                            }
                            Spacer()
                            Text(currencyViewModel.format(amountInBase: val))
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
        .id("category-avg-\(transactionSignature)-\(rangeStart?.timeIntervalSince1970 ?? 0)")
    }
}

struct CyberPercentagesView: View {
    let stats: InsightsStats
    let selectedMonth: MonthKey?
    let rangeStart: Date?
    let rangeEnd: Date?
    let transactionSignature: String

    private func rangePercents() -> [MoneyCategory: Double]? {
        guard let start = rangeStart else { return nil }
        let startOfDay = Calendar.current.startOfDay(for: start)
        let endOfDay: Date = rangeEnd.map {
            Calendar.current.date(byAdding: .day, value: 1, to: Calendar.current.startOfDay(for: $0)) ?? $0
        } ?? Date.distantFuture
        let request = NSFetchRequest<CDTransaction>(entityName: "CDTransaction")
        request.predicate = NSPredicate(
            format: "date >= %@ AND date < %@ AND typeRaw == %d",
            startOfDay as NSDate, endOfDay as NSDate, TransactionType.expense.rawValue
        )
        guard let txns = try? stats.context.fetch(request) else { return nil }
        var totals: [MoneyCategory: Double] = [:]
        for t in txns { totals[t.category, default: 0] += t.amount }
        let grand = totals.values.reduce(0, +)
        guard grand > 0 else { return nil }
        return totals.mapValues { ($0 / grand) * 100 }
    }

    private var sectionTitle: String {
        if let start = rangeStart {
            let f = DateFormatter(); f.dateFormat = "MMM d"
            if let end = rangeEnd { return "Distribution (\(f.string(from: start)) – \(f.string(from: end)))" }
            return "Distribution (From \(f.string(from: start)))"
        }
        return selectedMonth == nil ? "Spending Distribution" : "Distribution (\(selectedMonth!.title))"
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            CyberSectionHeader(title: sectionTitle)

            let percents: [MoneyCategory: Double] = rangePercents()
                ?? (selectedMonth == nil ? stats.percentPerCategoryOverall() : stats.percentPerCategoryForMonth(selectedMonth!))

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
                            CyberProgressBar(progress: percent / 100, barColor: category.color)
                        }
                    }
                }
            }
            .padding()
            .cyberCard()
        }
        .id("percentages-\(transactionSignature)-\(selectedMonth?.title ?? "all")-\(rangeStart?.timeIntervalSince1970 ?? 0)")
    }
}

struct CyberChartsView: View {
    let stats: InsightsStats
    let availableMonths: [MonthKey]
    let selectedMonth: MonthKey?
    let rangeStart: Date?
    let rangeEnd: Date?
    let transactionSignature: String

    var body: some View {
        VStack(spacing: 24) {
            CyberLast6MonthsChart(stats: stats, availableMonths: availableMonths)
                .id("last6-\(transactionSignature)")

            CyberCategoryPieChart(
                stats: stats,
                selectedMonth: selectedMonth,
                rangeStart: rangeStart,
                rangeEnd: rangeEnd,
                transactionSignature: transactionSignature
            )
            .id("pie-category-\(transactionSignature)-\(selectedMonth?.title ?? "all")-\(rangeStart?.timeIntervalSince1970 ?? 0)")

            CyberPaymentMethodPieChart(
                stats: stats,
                selectedMonth: selectedMonth,
                rangeStart: rangeStart,
                rangeEnd: rangeEnd,
                transactionSignature: transactionSignature
            )
            .id("pie-payment-\(transactionSignature)-\(selectedMonth?.title ?? "all")-\(rangeStart?.timeIntervalSince1970 ?? 0)")
        }
        .id("charts-\(transactionSignature)-\(selectedMonth?.title ?? "all")-\(rangeStart?.timeIntervalSince1970 ?? 0)")
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
    let rangeStart: Date?
    let rangeEnd: Date?
    let transactionSignature: String

    private func fetchAmounts(start: Date, end: Date) -> [MoneyCategory: Double] {
        let request = NSFetchRequest<CDTransaction>(entityName: "CDTransaction")
        request.predicate = NSPredicate(
            format: "date >= %@ AND date < %@ AND typeRaw == %d",
            start as NSDate, end as NSDate, TransactionType.expense.rawValue
        )
        var totals: [MoneyCategory: Double] = [:]
        for t in (try? stats.context.fetch(request)) ?? [] {
            totals[t.category, default: 0] += t.amount
        }
        return totals
    }

    private var chartData: [(category: String, amount: Double, percent: Double, color: Color)] {
        let amounts: [MoneyCategory: Double]
        let percents: [MoneyCategory: Double]

        if let start = rangeStart {
            let s = Calendar.current.startOfDay(for: start)
            let e: Date = rangeEnd.map { Calendar.current.date(byAdding: .day, value: 1, to: Calendar.current.startOfDay(for: $0)) ?? $0 } ?? Date.distantFuture
            amounts = fetchAmounts(start: s, end: e)
            let grand = amounts.values.reduce(0, +)
            guard grand > 0 else { return [] }
            percents = amounts.mapValues { ($0 / grand) * 100 }
        } else if let month = selectedMonth {
            percents = stats.percentPerCategoryForMonth(month)
            let startDate = month.startDate
            let endDate = Calendar.current.date(byAdding: .month, value: 1, to: startDate) ?? startDate
            amounts = fetchAmounts(start: startDate, end: endDate)
        } else {
            amounts = stats.allTimeTotalsPerCategory()
            let grandTotal = amounts.values.reduce(0, +)
            guard grandTotal > 0 else { return [] }
            percents = amounts.mapValues { ($0 / grandTotal) * 100 }
        }

        guard !percents.isEmpty else { return [] }
        return percents.compactMap { category, percent in
            guard percent > 0 else { return nil }
            return (category: category.rawValue, amount: amounts[category] ?? 0, percent: percent, color: category.color)
        }.sorted { $0.amount > $1.amount }
    }

    private var sectionTitle: String {
        if let start = rangeStart {
            let f = DateFormatter(); f.dateFormat = "MMM d"
            if let end = rangeEnd { return "Distribution (\(f.string(from: start)) – \(f.string(from: end)))" }
            return "Distribution (From \(f.string(from: start)))"
        }
        return selectedMonth == nil ? "Category Distribution" : "Distribution (\(selectedMonth!.title))"
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            CyberSectionHeader(title: sectionTitle)
            
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
    let rangeStart: Date?
    let rangeEnd: Date?
    let transactionSignature: String

    private func fetchAmounts(start: Date, end: Date) -> [PaymentMethod: Double] {
        let request = NSFetchRequest<CDTransaction>(entityName: "CDTransaction")
        request.predicate = NSPredicate(
            format: "date >= %@ AND date < %@ AND typeRaw == %d",
            start as NSDate, end as NSDate, TransactionType.expense.rawValue
        )
        var totals: [PaymentMethod: Double] = [:]
        for t in (try? stats.context.fetch(request)) ?? [] {
            totals[t.paymentMethod, default: 0] += t.amount
        }
        return totals
    }

    private var chartData: [(method: String, amount: Double, percent: Double, color: Color)] {
        let amounts: [PaymentMethod: Double]
        let percents: [PaymentMethod: Double]

        if let start = rangeStart {
            let s = Calendar.current.startOfDay(for: start)
            let e: Date = rangeEnd.map { Calendar.current.date(byAdding: .day, value: 1, to: Calendar.current.startOfDay(for: $0)) ?? $0 } ?? Date.distantFuture
            amounts = fetchAmounts(start: s, end: e)
            let grand = amounts.values.reduce(0, +)
            guard grand > 0 else { return [] }
            percents = amounts.mapValues { ($0 / grand) * 100 }
        } else if let month = selectedMonth {
            percents = stats.percentPerPaymentMethodForMonth(month)
            let startDate = month.startDate
            let endDate = Calendar.current.date(byAdding: .month, value: 1, to: startDate) ?? startDate
            amounts = fetchAmounts(start: startDate, end: endDate)
        } else {
            amounts = stats.allTimeTotalsPerPaymentMethod()
            let grandTotal = amounts.values.reduce(0, +)
            guard grandTotal > 0 else { return [] }
            percents = amounts.mapValues { ($0 / grandTotal) * 100 }
        }

        guard !percents.isEmpty else { return [] }
        return percents.compactMap { method, percent in
            guard percent > 0 else { return nil }
            return (method: method.rawValue, amount: amounts[method] ?? 0, percent: percent, color: paymentMethodColor(method))
        }.sorted { $0.amount > $1.amount }
    }

    private var sectionTitle: String {
        if let start = rangeStart {
            let f = DateFormatter(); f.dateFormat = "MMM d"
            if let end = rangeEnd { return "Payment Methods (\(f.string(from: start)) – \(f.string(from: end)))" }
            return "Payment Methods (From \(f.string(from: start)))"
        }
        return selectedMonth == nil ? "Payment Method Distribution" : "Payment Methods (\(selectedMonth!.title))"
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            CyberSectionHeader(title: sectionTitle)
            
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

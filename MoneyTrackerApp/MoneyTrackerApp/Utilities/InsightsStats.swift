import CoreData
import Foundation

struct InsightsStats {
    let context: NSManagedObjectContext
    
    func allTimeTotalsPerCategory() -> [MoneyCategory: Double] {
        let request = NSFetchRequest<CDTransaction>(entityName: "CDTransaction")
        request.predicate = NSPredicate(format: "typeRaw == %d", TransactionType.expense.rawValue)
        
        guard let transactions = try? context.fetch(request) else {
            return [:]
        }
        
        var totals: [MoneyCategory: Double] = [:]
        for transaction in transactions {
            let category = transaction.category
            totals[category, default: 0] += transaction.amount
        }
        
        return totals
    }
    
    func monthlyTotals() -> [MonthKey: Double] {
        let request = NSFetchRequest<CDTransaction>(entityName: "CDTransaction")
        request.predicate = NSPredicate(format: "typeRaw == %d", TransactionType.expense.rawValue)
        
        guard let transactions = try? context.fetch(request) else {
            return [:]
        }
        
        var totals: [MonthKey: Double] = [:]
        for transaction in transactions {
            let monthKey = transaction.date.monthKey()
            totals[monthKey, default: 0] += transaction.amount
        }
        
        return totals
    }
    
    func averagePerMonthOverall() -> Double {
        let monthly = monthlyTotals()
        guard !monthly.isEmpty else { return 0 }
        let total = monthly.values.reduce(0, +)
        return total / Double(monthly.count)
    }
    
    func averagePerMonthPerCategory() -> [MoneyCategory: Double] {
        let monthly = monthlyTotals()
        guard !monthly.isEmpty else { return [:] }
        
        var categoryMonthTotals: [MoneyCategory: [Double]] = [:]
        
        for (monthKey, _) in monthly {
            let request = NSFetchRequest<CDTransaction>(entityName: "CDTransaction")
            let startDate = monthKey.startDate
            let endDate = Calendar.current.date(byAdding: .month, value: 1, to: startDate) ?? startDate
            request.predicate = NSPredicate(format: "date >= %@ AND date < %@ AND typeRaw == %d",
                                           startDate as NSDate,
                                           endDate as NSDate,
                                           TransactionType.expense.rawValue)
            
            if let transactions = try? context.fetch(request) {
                var monthTotals: [MoneyCategory: Double] = [:]
                for transaction in transactions {
                    let category = transaction.category
                    monthTotals[category, default: 0] += transaction.amount
                }
                
                for (category, total) in monthTotals {
                    categoryMonthTotals[category, default: []].append(total)
                }
            }
        }
        
        var averages: [MoneyCategory: Double] = [:]
        for (category, totals) in categoryMonthTotals {
            averages[category] = totals.reduce(0, +) / Double(totals.count)
        }
        
        return averages
    }
    
    func percentPerCategoryOverall() -> [MoneyCategory: Double] {
        let totals = allTimeTotalsPerCategory()
        let grandTotal = totals.values.reduce(0, +)
        guard grandTotal > 0 else { return [:] }
        
        var percents: [MoneyCategory: Double] = [:]
        for (category, total) in totals {
            percents[category] = (total / grandTotal) * 100
        }
        
        return percents
    }
    
    func percentPerCategoryForMonth(_ month: MonthKey) -> [MoneyCategory: Double] {
        let startDate = month.startDate
        let endDate = Calendar.current.date(byAdding: .month, value: 1, to: startDate) ?? startDate
        
        let request = NSFetchRequest<CDTransaction>(entityName: "CDTransaction")
        request.predicate = NSPredicate(format: "date >= %@ AND date < %@ AND typeRaw == %d",
                                       startDate as NSDate,
                                       endDate as NSDate,
                                       TransactionType.expense.rawValue)
        
        guard let transactions = try? context.fetch(request) else {
            return [:]
        }
        
        var totals: [MoneyCategory: Double] = [:]
        for transaction in transactions {
            let category = transaction.category
            totals[category, default: 0] += transaction.amount
        }
        
        let grandTotal = totals.values.reduce(0, +)
        guard grandTotal > 0 else { return [:] }
        
        var percents: [MoneyCategory: Double] = [:]
        for (category, total) in totals {
            percents[category] = (total / grandTotal) * 100
        }
        
        return percents
    }
    
    // MARK: - Payment Method Statistics
    
    func allTimeTotalsPerPaymentMethod() -> [PaymentMethod: Double] {
        let request = NSFetchRequest<CDTransaction>(entityName: "CDTransaction")
        request.predicate = NSPredicate(format: "typeRaw == %d", TransactionType.expense.rawValue)
        
        guard let transactions = try? context.fetch(request) else {
            return [:]
        }
        
        var totals: [PaymentMethod: Double] = [:]
        for transaction in transactions {
            let method = transaction.paymentMethod
            totals[method, default: 0] += transaction.amount
        }
        
        return totals
    }
    
    func percentPerPaymentMethodOverall() -> [PaymentMethod: Double] {
        let totals = allTimeTotalsPerPaymentMethod()
        let grandTotal = totals.values.reduce(0, +)
        guard grandTotal > 0 else { return [:] }
        
        var percents: [PaymentMethod: Double] = [:]
        for (method, total) in totals {
            percents[method] = (total / grandTotal) * 100
        }
        
        return percents
    }
    
    func percentPerPaymentMethodForMonth(_ month: MonthKey) -> [PaymentMethod: Double] {
        let startDate = month.startDate
        let endDate = Calendar.current.date(byAdding: .month, value: 1, to: startDate) ?? startDate
        
        let request = NSFetchRequest<CDTransaction>(entityName: "CDTransaction")
        request.predicate = NSPredicate(format: "date >= %@ AND date < %@ AND typeRaw == %d",
                                       startDate as NSDate,
                                       endDate as NSDate,
                                       TransactionType.expense.rawValue)
        
        guard let transactions = try? context.fetch(request) else {
            return [:]
        }
        
        var totals: [PaymentMethod: Double] = [:]
        for transaction in transactions {
            let method = transaction.paymentMethod
            totals[method, default: 0] += transaction.amount
        }
        
        let grandTotal = totals.values.reduce(0, +)
        guard grandTotal > 0 else { return [:] }
        
        var percents: [PaymentMethod: Double] = [:]
        for (method, total) in totals {
            percents[method] = (total / grandTotal) * 100
        }
        
        return percents
    }
}


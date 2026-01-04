import Foundation

enum MoneyCategory: String, CaseIterable, Identifiable {
    case housing = "Housing"
    case fixedBills = "Fixed Bills"
    case food = "Food"
    case transportation = "Transportation"
    case healthcare = "Healthcare"
    case funLifestyle = "Fun/Lifestyle"
    case shopping = "Shopping"
    case subscriptions = "Subscriptions"
    case savings = "Savings"
    case investing = "Investing"
    case travel = "Travel"
    case gifts = "Gifts"
    case misc = "Misc"
    var id: String { rawValue }
}

enum PaymentMethod: String, CaseIterable, Identifiable {
    case cash = "Cash"
    case debit = "Debit"
    case credit = "Credit"
    case applePay = "Apple Pay"
    case venmo = "Venmo"
    case other = "Other"
    var id: String { rawValue }
}

enum TransactionType: Int16, CaseIterable, Identifiable {
    case expense = 0
    case income = 1
    case transfer = 2
    var id: Int16 { rawValue }

    var label: String {
        switch self {
        case .expense: return "Expense"
        case .income: return "Income"
        case .transfer: return "Transfer"
        }
    }
}

enum RecurringInterval: String, CaseIterable, Identifiable {
    case monthly = "monthly"
    var id: String { rawValue }
}

struct MonthKey: Hashable, Comparable {
    let year: Int
    let month: Int

    static func < (lhs: MonthKey, rhs: MonthKey) -> Bool {
        if lhs.year != rhs.year { return lhs.year < rhs.year }
        return lhs.month < rhs.month
    }

    var startDate: Date {
        Calendar.current.date(from: DateComponents(year: year, month: month, day: 1)) ?? Date()
    }

    var title: String {
        let df = DateFormatter()
        df.dateFormat = "MMMM yyyy"
        return df.string(from: startDate)
    }
}

extension Date {
    func monthKey() -> MonthKey {
        let c = Calendar.current.dateComponents([.year, .month], from: self)
        return MonthKey(year: c.year ?? 1970, month: c.month ?? 1)
    }

    func startOfMonth() -> Date {
        let c = Calendar.current.dateComponents([.year, .month], from: self)
        return Calendar.current.date(from: DateComponents(year: c.year, month: c.month, day: 1)) ?? self
    }
}

extension Double {
    func currency() -> String {
        let f = NumberFormatter()
        f.numberStyle = .currency
        return f.string(from: NSNumber(value: self)) ?? "$\(self)"
    }
}


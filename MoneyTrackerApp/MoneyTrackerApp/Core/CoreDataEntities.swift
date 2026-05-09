import CoreData
import Foundation

@objc(CDTransaction)
public final class CDTransaction: NSManagedObject {}

extension CDTransaction {
    @nonobjc public class func fetchRequest() -> NSFetchRequest<CDTransaction> {
        NSFetchRequest<CDTransaction>(entityName: "CDTransaction")
    }

    @NSManaged public var id: UUID
    @NSManaged public var date: Date
    /// Frozen USD-equivalent at log time. Snapshotted via originalAmount * rateToUSD when saved.
    @NSManaged public var amount: Double
    @NSManaged public var categoryRaw: String
    @NSManaged public var merchant: String?
    @NSManaged public var paymentMethodRaw: String?
    @NSManaged public var notes: String?
    @NSManaged public var typeRaw: Int16

    /// Currency code the user entered the amount in (e.g. "EUR"). Nil = legacy row, treat amount as USD.
    @NSManaged public var originalCurrencyRaw: String?
    /// Amount as originally entered, in originalCurrencyRaw. Authoritative when originalCurrencyRaw is non-nil.
    @NSManaged public var originalAmount: Double

    @NSManaged public var isRecurring: Bool
    @NSManaged public var recurringIntervalRaw: String?
    @NSManaged public var recurringGroupId: UUID?
    @NSManaged public var generatedFromRecurringId: UUID?

    @NSManaged public var createdAt: Date

    var category: MoneyCategory { MoneyCategory(rawValue: categoryRaw) ?? .misc }
    var paymentMethod: PaymentMethod { PaymentMethod(rawValue: paymentMethodRaw ?? "") ?? .other }
    var type: TransactionType { TransactionType(rawValue: typeRaw) ?? .expense }
    var recurringInterval: RecurringInterval? {
        guard let raw = recurringIntervalRaw else { return nil }
        return RecurringInterval(rawValue: raw)
    }

    /// The currency the transaction was originally logged in. Defaults to USD for legacy rows that pre-date the snapshot fields.
    var originalCurrency: AppCurrency {
        if let raw = originalCurrencyRaw, let currency = AppCurrency(rawValue: raw) {
            return currency
        }
        return .usd
    }

    /// True if this row has a per-log currency snapshot. False for legacy rows (treat amount as USD).
    var hasCurrencySnapshot: Bool { originalCurrencyRaw != nil }
}

@objc(CDPreset)
public final class CDPreset: NSManagedObject {}

extension CDPreset {
    @nonobjc public class func fetchRequest() -> NSFetchRequest<CDPreset> {
        NSFetchRequest<CDPreset>(entityName: "CDPreset")
    }

    @NSManaged public var id: UUID
    @NSManaged public var name: String
    @NSManaged public var defaultCategoryRaw: String
    @NSManaged public var defaultMerchant: String?
    @NSManaged public var defaultPaymentMethodRaw: String?
    @NSManaged public var defaultNotes: String?
    @NSManaged public var defaultAmount: Double

    var defaultCategory: MoneyCategory { MoneyCategory(rawValue: defaultCategoryRaw) ?? .misc }
    var defaultPaymentMethod: PaymentMethod { PaymentMethod(rawValue: defaultPaymentMethodRaw ?? "") ?? .other }
}

@objc(CDBudget)
public final class CDBudget: NSManagedObject {}

extension CDBudget {
    @nonobjc public class func fetchRequest() -> NSFetchRequest<CDBudget> {
        NSFetchRequest<CDBudget>(entityName: "CDBudget")
    }

    @NSManaged public var id: UUID
    @NSManaged public var monthStart: Date
    @NSManaged public var categoryRaw: String
    @NSManaged public var limit: Double

    var category: MoneyCategory { MoneyCategory(rawValue: categoryRaw) ?? .misc }
}

extension CDTransaction: Identifiable {}
extension CDPreset: Identifiable {}
extension CDBudget: Identifiable {}


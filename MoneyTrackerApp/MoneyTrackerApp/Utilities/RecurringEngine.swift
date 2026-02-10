import CoreData
import Foundation

struct RecurringEngine {
    let context: NSManagedObjectContext
    private let calendar = Calendar.current
    
    func generateForMonth(_ month: MonthKey) {
        guard let templates = fetchRecurringTemplates(), !templates.isEmpty else { return }
        
        for template in templates {
            generateMonthlyInstanceIfNeeded(for: template, month: month, onlyIfDueBy: nil)
        }
        
        PersistenceController.shared.save(context)
    }
    
    func generateDueTransactions(asOf now: Date = Date()) {
        guard let templates = fetchRecurringTemplates(), !templates.isEmpty else { return }
        
        let currentMonth = now.monthKey()
        
        for template in templates {
            guard template.recurringInterval == .monthly else { continue }
            
            var month = nextMonth(after: template.date.monthKey())
            while month <= currentMonth {
                generateMonthlyInstanceIfNeeded(for: template, month: month, onlyIfDueBy: now)
                month = nextMonth(after: month)
            }
        }
        
        PersistenceController.shared.save(context)
    }
    
    private func fetchRecurringTemplates() -> [CDTransaction]? {
        // Recurring templates are source entries (not generated children).
        let templateRequest = NSFetchRequest<CDTransaction>(entityName: "CDTransaction")
        templateRequest.predicate = NSPredicate(format: "isRecurring == YES AND generatedFromRecurringId == nil")
        return try? context.fetch(templateRequest)
    }
    
    private func generateMonthlyInstanceIfNeeded(
        for template: CDTransaction,
        month: MonthKey,
        onlyIfDueBy dueDate: Date?
    ) {
        guard let groupId = template.recurringGroupId,
              template.recurringInterval == .monthly else { return }
        
        // The template entry itself is the first occurrence month.
        guard month > template.date.monthKey() else { return }
        
        let instanceDate = monthlyOccurrenceDate(for: template.date, in: month)
        if let dueDate, instanceDate > dueDate {
            return
        }
        
        guard !hasGeneratedInstance(groupId: groupId, month: month) else { return }
        
        let instance = CDTransaction(context: context)
        instance.id = UUID()
        instance.date = instanceDate
        instance.amount = template.amount
        instance.categoryRaw = template.categoryRaw
        instance.merchant = template.merchant
        instance.paymentMethodRaw = template.paymentMethodRaw
        instance.notes = template.notes
        instance.typeRaw = template.typeRaw
        instance.isRecurring = false
        instance.recurringIntervalRaw = nil
        instance.recurringGroupId = groupId
        instance.generatedFromRecurringId = groupId
        instance.createdAt = Date()
    }
    
    private func hasGeneratedInstance(groupId: UUID, month: MonthKey) -> Bool {
        let startDate = month.startDate
        let endDate = calendar.date(byAdding: .month, value: 1, to: startDate) ?? startDate
        
        let existingRequest = NSFetchRequest<CDTransaction>(entityName: "CDTransaction")
        existingRequest.fetchLimit = 1
        existingRequest.predicate = NSPredicate(
            format: "generatedFromRecurringId == %@ AND date >= %@ AND date < %@",
            groupId as CVarArg,
            startDate as NSDate,
            endDate as NSDate
        )
        
        return ((try? context.fetch(existingRequest)) ?? []).isEmpty == false
    }
    
    private func monthlyOccurrenceDate(for templateDate: Date, in month: MonthKey) -> Date {
        let startDate = month.startDate
        let requestedDay = calendar.component(.day, from: templateDate)
        let maxDayInMonth = (calendar.range(of: .day, in: .month, for: startDate)?.upperBound ?? 2) - 1
        let resolvedDay = min(requestedDay, maxDayInMonth)
        
        var components = calendar.dateComponents([.year, .month], from: startDate)
        let time = calendar.dateComponents([.hour, .minute, .second, .nanosecond], from: templateDate)
        components.day = resolvedDay
        components.hour = time.hour
        components.minute = time.minute
        components.second = time.second
        components.nanosecond = time.nanosecond
        
        return calendar.date(from: components) ?? startDate
    }
    
    private func nextMonth(after month: MonthKey) -> MonthKey {
        let nextMonthValue = month.month + 1
        if nextMonthValue > 12 {
            return MonthKey(year: month.year + 1, month: 1)
        }
        return MonthKey(year: month.year, month: nextMonthValue)
    }
}


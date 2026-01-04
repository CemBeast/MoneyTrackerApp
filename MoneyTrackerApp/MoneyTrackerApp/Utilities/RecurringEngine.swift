import CoreData
import Foundation

struct RecurringEngine {
    let context: NSManagedObjectContext
    
    func generateForMonth(_ month: MonthKey) {
        let startDate = month.startDate
        let endDate = Calendar.current.date(byAdding: .month, value: 1, to: startDate) ?? startDate
        
        // Find all recurring templates (isRecurring == true, generatedFromRecurringId == nil)
        let templateRequest = NSFetchRequest<CDTransaction>(entityName: "CDTransaction")
        templateRequest.predicate = NSPredicate(format: "isRecurring == YES AND generatedFromRecurringId == nil")
        
        guard let templates = try? context.fetch(templateRequest) else { return }
        
        for template in templates {
            guard let groupId = template.recurringGroupId,
                  template.recurringInterval == .monthly else { continue }
            
            // Check if instance already exists for this month
            let existingRequest = NSFetchRequest<CDTransaction>(entityName: "CDTransaction")
            existingRequest.predicate = NSPredicate(format: "generatedFromRecurringId == %@ AND date >= %@ AND date < %@",
                                                   groupId as CVarArg,
                                                   startDate as NSDate,
                                                   endDate as NSDate)
            
            if let existing = try? context.fetch(existingRequest), !existing.isEmpty {
                continue // Already generated
            }
            
            // Create new instance
            let instance = CDTransaction(context: context)
            instance.id = UUID()
            instance.date = startDate
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
        
        PersistenceController.shared.save(context)
    }
}


//
//  LegacyRecurringMigration.swift
//  MoneyTrackerApp
//
//  Converts pre-schedule recurring data (a CDTransaction acting as both first log and template)
//  into CDRecurringSchedule rules. Idempotent: once converted, a template no longer matches.
//

import CoreData
import Foundation

enum LegacyRecurringMigration {

    /// Changes are left unsaved; callers save (the engine saves after generating, backup import saves after restoring).
    static func run(in context: NSManagedObjectContext) {
        convertTemplates(in: context)
        backfillGeneratedInstances(in: context)
    }

    private static func convertTemplates(in context: NSManagedObjectContext) {
        let request = NSFetchRequest<CDTransaction>(entityName: "CDTransaction")
        request.predicate = NSPredicate(format: "isRecurring == YES AND generatedFromRecurringId == nil")
        guard let templates = try? context.fetch(request), !templates.isEmpty else { return }

        for template in templates {
            guard let interval = template.recurringInterval else {
                template.isRecurring = false
                continue
            }

            // Reuse the group id so existing generated logs and skip markers stay linked.
            let scheduleId = template.recurringGroupId ?? UUID()
            if existingSchedule(id: scheduleId, in: context) == nil {
                let schedule = CDRecurringSchedule(context: context)
                schedule.id = scheduleId
                schedule.startDate = Calendar.current.startOfDay(for: template.date)
                schedule.intervalRaw = interval.rawValue
                schedule.amount = template.amount
                schedule.originalCurrencyRaw = template.originalCurrencyRaw
                schedule.originalAmount = template.originalAmount
                schedule.categoryRaw = template.categoryRaw
                schedule.merchant = template.merchant
                schedule.paymentMethodRaw = template.paymentMethodRaw
                schedule.notes = template.notes
                schedule.typeRaw = template.typeRaw
                schedule.createdAt = template.createdAt
            }

            if template.isScheduleOnly {
                // The user already deleted this first log; keep it deleted.
                let skipped = CDSkippedOccurrence(context: context)
                skipped.id = UUID()
                skipped.groupId = scheduleId
                skipped.date = template.date
                context.delete(template)
            } else {
                // The template's own row becomes the schedule's first generated log.
                template.isRecurring = false
                template.recurringGroupId = nil
                template.generatedFromRecurringId = scheduleId
                template.occurrenceDate = template.date
            }
        }
    }

    /// Older generated logs may lack occurrenceDate or the interval used for the badge.
    private static func backfillGeneratedInstances(in context: NSManagedObjectContext) {
        let request = NSFetchRequest<CDTransaction>(entityName: "CDTransaction")
        request.predicate = NSPredicate(
            format: "generatedFromRecurringId != nil AND (occurrenceDate == nil OR recurringIntervalRaw == nil)"
        )
        guard let instances = try? context.fetch(request), !instances.isEmpty else { return }

        let schedules = (try? context.fetch(NSFetchRequest<CDRecurringSchedule>(entityName: "CDRecurringSchedule"))) ?? []
        let intervalById = Dictionary(schedules.map { ($0.id, $0.intervalRaw) }, uniquingKeysWith: { first, _ in first })

        for instance in instances {
            if instance.occurrenceDate == nil {
                // Best effort: assume the current date is the scheduled one.
                instance.occurrenceDate = instance.date
            }
            if instance.recurringIntervalRaw == nil, let id = instance.generatedFromRecurringId {
                instance.recurringIntervalRaw = intervalById[id]
            }
        }
    }

    private static func existingSchedule(id: UUID, in context: NSManagedObjectContext) -> CDRecurringSchedule? {
        let request = NSFetchRequest<CDRecurringSchedule>(entityName: "CDRecurringSchedule")
        request.fetchLimit = 1
        request.predicate = NSPredicate(format: "id == %@", id as CVarArg)
        return try? context.fetch(request).first
    }
}

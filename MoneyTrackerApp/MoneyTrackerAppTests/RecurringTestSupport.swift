//
//  RecurringTestSupport.swift
//  MoneyTrackerAppTests
//
//  Shared fixtures for recurring tests. All dates are fixed so month-end and leap-year cases are deterministic.
//

import CoreData
import Foundation
@testable import MoneyTrackerApp

@MainActor
enum RecurringFixtures {

    static func makeContext() -> NSManagedObjectContext {
        PersistenceController.inMemoryForTesting().container.viewContext
    }

    static func date(_ year: Int, _ month: Int, _ day: Int, hour: Int = 0, minute: Int = 0) -> Date {
        Calendar.current.date(from: DateComponents(year: year, month: month, day: day, hour: hour, minute: minute))!
    }

    @discardableResult
    static func makeSchedule(
        in context: NSManagedObjectContext,
        interval: RecurringInterval,
        start: Date,
        amount: Double = 10.0,
        merchant: String = "Spotify"
    ) -> CDRecurringSchedule {
        let schedule = CDRecurringSchedule(context: context)
        schedule.id = UUID()
        schedule.startDate = Calendar.current.startOfDay(for: start)
        schedule.intervalRaw = interval.rawValue
        schedule.amount = amount
        schedule.originalCurrencyRaw = AppCurrency.usd.rawValue
        schedule.originalAmount = amount
        schedule.categoryRaw = MoneyCategory.subscriptions.rawValue
        schedule.merchant = merchant
        schedule.paymentMethodRaw = PaymentMethod.credit.rawValue
        schedule.notes = "Recurring"
        schedule.typeRaw = TransactionType.expense.rawValue
        schedule.createdAt = Date()
        return schedule
    }

    @discardableResult
    static func makeLog(
        in context: NSManagedObjectContext,
        date: Date,
        amount: Double = 10.0,
        merchant: String = "Spotify"
    ) -> CDTransaction {
        let txn = CDTransaction(context: context)
        txn.id = UUID()
        txn.date = date
        txn.amount = amount
        txn.originalCurrencyRaw = AppCurrency.usd.rawValue
        txn.originalAmount = amount
        txn.categoryRaw = MoneyCategory.subscriptions.rawValue
        txn.merchant = merchant
        txn.paymentMethodRaw = PaymentMethod.credit.rawValue
        txn.typeRaw = TransactionType.expense.rawValue
        txn.createdAt = Date()
        return txn
    }

    /// Pre-schedule recurring data: a transaction acting as both first log and template.
    @discardableResult
    static func makeLegacyTemplate(
        in context: NSManagedObjectContext,
        interval: RecurringInterval,
        date: Date,
        groupId: UUID = UUID(),
        scheduleOnly: Bool = false
    ) -> CDTransaction {
        let template = makeLog(in: context, date: date)
        template.isRecurring = true
        template.recurringIntervalRaw = interval.rawValue
        template.recurringGroupId = groupId
        template.isScheduleOnly = scheduleOnly
        return template
    }

    /// Legacy generated instance (pre-occurrenceDate), linked to a template's group.
    @discardableResult
    static func makeLegacyInstance(in context: NSManagedObjectContext, groupId: UUID, date: Date) -> CDTransaction {
        let instance = makeLog(in: context, date: date)
        instance.generatedFromRecurringId = groupId
        return instance
    }

    static func generate(in context: NSManagedObjectContext, asOf now: Date) {
        RecurringEngine(context: context).generateDueTransactions(asOf: now)
    }

    /// Logs linked to a schedule, sorted by date.
    static func logs(in context: NSManagedObjectContext, scheduleId: UUID) -> [CDTransaction] {
        let request = NSFetchRequest<CDTransaction>(entityName: "CDTransaction")
        request.predicate = NSPredicate(format: "generatedFromRecurringId == %@", scheduleId as CVarArg)
        request.sortDescriptors = [NSSortDescriptor(keyPath: \CDTransaction.date, ascending: true)]
        return (try? context.fetch(request)) ?? []
    }

    static func allLogs(in context: NSManagedObjectContext) -> [CDTransaction] {
        let request = NSFetchRequest<CDTransaction>(entityName: "CDTransaction")
        request.sortDescriptors = [NSSortDescriptor(keyPath: \CDTransaction.date, ascending: true)]
        return (try? context.fetch(request)) ?? []
    }

    static func schedules(in context: NSManagedObjectContext) -> [CDRecurringSchedule] {
        (try? context.fetch(NSFetchRequest<CDRecurringSchedule>(entityName: "CDRecurringSchedule"))) ?? []
    }

    static func skipMarkers(in context: NSManagedObjectContext) -> [CDSkippedOccurrence] {
        (try? context.fetch(NSFetchRequest<CDSkippedOccurrence>(entityName: "CDSkippedOccurrence"))) ?? []
    }

    /// Mirrors LogView's delete: tombstone generated logs, then delete.
    static func deleteLog(_ log: CDTransaction, in context: NSManagedObjectContext) throws {
        RecurringEngine.recordSkippedOccurrence(for: log, in: context)
        context.delete(log)
        try context.save()
    }

    static func days(_ logs: [CDTransaction]) -> [Date] {
        logs.map { Calendar.current.startOfDay(for: $0.date) }
    }
}

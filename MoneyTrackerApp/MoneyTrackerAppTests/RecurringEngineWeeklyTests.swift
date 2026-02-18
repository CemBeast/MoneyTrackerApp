//
//  RecurringEngineWeeklyTests.swift
//  MoneyTrackerAppTests
//
//  Tests that weekly recurring transactions are automatically generated
//  when a week has passed since the template date.
//

import CoreData
import Foundation
import Testing
@testable import MoneyTrackerApp

@Suite("Weekly Recurring Transaction Generation")
struct RecurringEngineWeeklyTests {

    /// Creates an in-memory persistence controller for isolated testing.
    private func makeTestController() -> PersistenceController {
        PersistenceController.inMemoryForTesting()
    }

    /// Creates a weekly recurring template transaction.
    /// - Parameters:
    ///   - context: The Core Data context to insert into
    ///   - date: The template's transaction date (first occurrence)
    ///   - amount: Transaction amount
    ///   - groupId: Optional UUID; if nil, a new one is created
    /// - Returns: The created CDTransaction template
    private func createWeeklyTemplate(
        context: NSManagedObjectContext,
        date: Date,
        amount: Double = 50.0,
        groupId: UUID? = nil
    ) -> CDTransaction {
        let template = CDTransaction(context: context)
        template.id = UUID()
        template.date = date
        template.amount = amount
        template.categoryRaw = MoneyCategory.food.rawValue
        template.merchant = "Weekly Groceries"
        template.paymentMethodRaw = PaymentMethod.debit.rawValue
        template.notes = "Recurring weekly"
        template.typeRaw = TransactionType.expense.rawValue
        template.isRecurring = true
        template.recurringIntervalRaw = RecurringInterval.weekly.rawValue
        template.recurringGroupId = groupId ?? UUID()
        template.generatedFromRecurringId = nil
        template.createdAt = Date()
        return template
    }

    /// Counts generated instances (transactions with generatedFromRecurringId set) for a group.
    private func countGeneratedInstances(
        context: NSManagedObjectContext,
        groupId: UUID
    ) -> Int {
        let request = NSFetchRequest<CDTransaction>(entityName: "CDTransaction")
        request.predicate = NSPredicate(format: "generatedFromRecurringId == %@", groupId as CVarArg)
        let results = (try? context.fetch(request)) ?? []
        return results.count
    }

    @Test("Weekly template from 1 week ago generates exactly 1 instance when due")
    func oneWeekAgoGeneratesOneInstance() throws {
        let controller = makeTestController()
        let context = controller.container.viewContext

        let calendar = Calendar.current
        let oneWeekAgo = calendar.date(byAdding: .day, value: -7, to: Date())!

        let groupId = UUID()
        _ = createWeeklyTemplate(context: context, date: oneWeekAgo, groupId: groupId)
        try context.save()

        let engine = RecurringEngine(context: context)
        engine.generateDueTransactions(asOf: Date())

        let generated = countGeneratedInstances(context: context, groupId: groupId)
        #expect(generated == 1, "Expected 1 generated instance when template is 1 week old")
    }

    @Test("Weekly template from 3 weeks ago generates 3 instances")
    func threeWeeksAgoGeneratesThreeInstances() throws {
        let controller = makeTestController()
        let context = controller.container.viewContext

        let calendar = Calendar.current
        let threeWeeksAgo = calendar.date(byAdding: .day, value: -21, to: Date())!

        let groupId = UUID()
        _ = createWeeklyTemplate(context: context, date: threeWeeksAgo, groupId: groupId)
        try context.save()

        let engine = RecurringEngine(context: context)
        engine.generateDueTransactions(asOf: Date())

        let generated = countGeneratedInstances(context: context, groupId: groupId)
        #expect(generated == 3, "Expected 3 generated instances when template is 3 weeks old")
    }

    @Test("Weekly template from 6 days ago generates 0 instances (less than a week)")
    func sixDaysAgoGeneratesNoInstances() throws {
        let controller = makeTestController()
        let context = controller.container.viewContext

        let calendar = Calendar.current
        let sixDaysAgo = calendar.date(byAdding: .day, value: -6, to: Date())!

        let groupId = UUID()
        _ = createWeeklyTemplate(context: context, date: sixDaysAgo, groupId: groupId)
        try context.save()

        let engine = RecurringEngine(context: context)
        engine.generateDueTransactions(asOf: Date())

        let generated = countGeneratedInstances(context: context, groupId: groupId)
        #expect(generated == 0, "Expected 0 generated instances when template is only 6 days old")
    }

    @Test("Weekly template from exactly 7 days ago generates 1 instance")
    func exactlySevenDaysAgoGeneratesOneInstance() throws {
        let controller = makeTestController()
        let context = controller.container.viewContext

        let calendar = Calendar.current
        let sevenDaysAgo = calendar.date(byAdding: .day, value: -7, to: Date())!

        let groupId = UUID()
        _ = createWeeklyTemplate(context: context, date: sevenDaysAgo, groupId: groupId)
        try context.save()

        let engine = RecurringEngine(context: context)
        engine.generateDueTransactions(asOf: Date())

        let generated = countGeneratedInstances(context: context, groupId: groupId)
        #expect(generated == 1, "Expected 1 generated instance when template is exactly 7 days old")
    }

    @Test("Calling generateDueTransactions twice does not create duplicates")
    func noDuplicatesOnSecondRun() throws {
        let controller = makeTestController()
        let context = controller.container.viewContext

        let calendar = Calendar.current
        let twoWeeksAgo = calendar.date(byAdding: .day, value: -14, to: Date())!

        let groupId = UUID()
        _ = createWeeklyTemplate(context: context, date: twoWeeksAgo, groupId: groupId)
        try context.save()

        let engine = RecurringEngine(context: context)
        engine.generateDueTransactions(asOf: Date())
        let firstRunCount = countGeneratedInstances(context: context, groupId: groupId)

        engine.generateDueTransactions(asOf: Date())
        let secondRunCount = countGeneratedInstances(context: context, groupId: groupId)

        #expect(firstRunCount == 2, "Expected 2 instances after first run (2 weeks)")
        #expect(secondRunCount == 2, "Expected no new instances on second run; got \(secondRunCount)")
    }

    @Test("Generated instance has correct amount and category from template")
    func generatedInstanceMatchesTemplate() throws {
        let controller = makeTestController()
        let context = controller.container.viewContext

        let calendar = Calendar.current
        let oneWeekAgo = calendar.date(byAdding: .day, value: -7, to: Date())!

        let groupId = UUID()
        let amount: Double = 99.50
        _ = createWeeklyTemplate(context: context, date: oneWeekAgo, amount: amount, groupId: groupId)
        try context.save()

        let engine = RecurringEngine(context: context)
        engine.generateDueTransactions(asOf: Date())

        let request = NSFetchRequest<CDTransaction>(entityName: "CDTransaction")
        request.predicate = NSPredicate(format: "generatedFromRecurringId == %@", groupId as CVarArg)
        let instances = (try? context.fetch(request)) ?? []

        #expect(instances.count == 1)
        #expect(instances[0].amount == amount)
        #expect(instances[0].categoryRaw == MoneyCategory.food.rawValue)
        #expect(instances[0].merchant == "Weekly Groceries")
        #expect(instances[0].isRecurring == false, "Generated instances should not be recurring templates")
    }
}

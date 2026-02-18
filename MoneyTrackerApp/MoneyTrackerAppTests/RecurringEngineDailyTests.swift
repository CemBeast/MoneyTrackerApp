//
//  RecurringEngineDailyTests.swift
//  MoneyTrackerAppTests
//
//  Tests that daily recurring transactions are automatically generated
//  when a day has passed since the template date.
//

import CoreData
import Foundation
import Testing
@testable import MoneyTrackerApp

@Suite("Daily Recurring Transaction Generation")
struct RecurringEngineDailyTests {

    private func makeTestController() -> PersistenceController {
        PersistenceController.inMemoryForTesting()
    }

    private func createDailyTemplate(
        context: NSManagedObjectContext,
        date: Date,
        amount: Double = 25.0,
        groupId: UUID? = nil
    ) -> CDTransaction {
        let template = CDTransaction(context: context)
        template.id = UUID()
        template.date = date
        template.amount = amount
        template.categoryRaw = MoneyCategory.transportation.rawValue
        template.merchant = "Daily Transit"
        template.paymentMethodRaw = PaymentMethod.applePay.rawValue
        template.notes = "Recurring daily"
        template.typeRaw = TransactionType.expense.rawValue
        template.isRecurring = true
        template.recurringIntervalRaw = RecurringInterval.daily.rawValue
        template.recurringGroupId = groupId ?? UUID()
        template.generatedFromRecurringId = nil
        template.createdAt = Date()
        return template
    }

    private func countGeneratedInstances(
        context: NSManagedObjectContext,
        groupId: UUID
    ) -> Int {
        let request = NSFetchRequest<CDTransaction>(entityName: "CDTransaction")
        request.predicate = NSPredicate(format: "generatedFromRecurringId == %@", groupId as CVarArg)
        let results = (try? context.fetch(request)) ?? []
        return results.count
    }

    @Test("Daily template from 1 day ago generates exactly 1 instance when due")
    func oneDayAgoGeneratesOneInstance() throws {
        let controller = makeTestController()
        let context = controller.container.viewContext
        let calendar = Calendar.current
        let oneDayAgo = calendar.date(byAdding: .day, value: -1, to: Date())!

        let groupId = UUID()
        _ = createDailyTemplate(context: context, date: oneDayAgo, groupId: groupId)
        try context.save()

        let engine = RecurringEngine(context: context)
        engine.generateDueTransactions(asOf: Date())

        let generated = countGeneratedInstances(context: context, groupId: groupId)
        #expect(generated == 1, "Expected 1 generated instance when template is 1 day old")
    }

    @Test("Daily template from 5 days ago generates 5 instances")
    func fiveDaysAgoGeneratesFiveInstances() throws {
        let controller = makeTestController()
        let context = controller.container.viewContext
        let calendar = Calendar.current
        let fiveDaysAgo = calendar.date(byAdding: .day, value: -5, to: Date())!

        let groupId = UUID()
        _ = createDailyTemplate(context: context, date: fiveDaysAgo, groupId: groupId)
        try context.save()

        let engine = RecurringEngine(context: context)
        engine.generateDueTransactions(asOf: Date())

        let generated = countGeneratedInstances(context: context, groupId: groupId)
        #expect(generated == 5, "Expected 5 generated instances when template is 5 days old")
    }

    @Test("Daily template from 23 hours ago generates 0 instances (less than a full day)")
    func twentyThreeHoursAgoGeneratesNoInstances() throws {
        let controller = makeTestController()
        let context = controller.container.viewContext
        let twentyThreeHoursAgo = Date().addingTimeInterval(-23 * 3600)

        let groupId = UUID()
        _ = createDailyTemplate(context: context, date: twentyThreeHoursAgo, groupId: groupId)
        try context.save()

        let engine = RecurringEngine(context: context)
        engine.generateDueTransactions(asOf: Date())

        let generated = countGeneratedInstances(context: context, groupId: groupId)
        #expect(generated == 0, "Expected 0 generated instances when template is only 23 hours old")
    }

    @Test("Daily template from exactly 24 hours ago generates 1 instance")
    func exactlyOneDayAgoGeneratesOneInstance() throws {
        let controller = makeTestController()
        let context = controller.container.viewContext
        let oneDayAgo = Date().addingTimeInterval(-24 * 3600)

        let groupId = UUID()
        _ = createDailyTemplate(context: context, date: oneDayAgo, groupId: groupId)
        try context.save()

        let engine = RecurringEngine(context: context)
        engine.generateDueTransactions(asOf: Date())

        let generated = countGeneratedInstances(context: context, groupId: groupId)
        #expect(generated == 1, "Expected 1 generated instance when template is exactly 1 day old")
    }

    @Test("Calling generateDueTransactions twice does not create duplicates")
    func noDuplicatesOnSecondRun() throws {
        let controller = makeTestController()
        let context = controller.container.viewContext
        let calendar = Calendar.current
        let threeDaysAgo = calendar.date(byAdding: .day, value: -3, to: Date())!

        let groupId = UUID()
        _ = createDailyTemplate(context: context, date: threeDaysAgo, groupId: groupId)
        try context.save()

        let engine = RecurringEngine(context: context)
        engine.generateDueTransactions(asOf: Date())
        let firstRunCount = countGeneratedInstances(context: context, groupId: groupId)

        engine.generateDueTransactions(asOf: Date())
        let secondRunCount = countGeneratedInstances(context: context, groupId: groupId)

        #expect(firstRunCount == 3, "Expected 3 instances after first run (3 days)")
        #expect(secondRunCount == 3, "Expected no new instances on second run; got \(secondRunCount)")
    }

    @Test("Generated instance has correct amount and category from template")
    func generatedInstanceMatchesTemplate() throws {
        let controller = makeTestController()
        let context = controller.container.viewContext
        let calendar = Calendar.current
        let oneDayAgo = calendar.date(byAdding: .day, value: -1, to: Date())!

        let groupId = UUID()
        let amount: Double = 12.75
        _ = createDailyTemplate(context: context, date: oneDayAgo, amount: amount, groupId: groupId)
        try context.save()

        let engine = RecurringEngine(context: context)
        engine.generateDueTransactions(asOf: Date())

        let request = NSFetchRequest<CDTransaction>(entityName: "CDTransaction")
        request.predicate = NSPredicate(format: "generatedFromRecurringId == %@", groupId as CVarArg)
        let instances = (try? context.fetch(request)) ?? []

        #expect(instances.count == 1)
        #expect(instances[0].amount == amount)
        #expect(instances[0].categoryRaw == MoneyCategory.transportation.rawValue)
        #expect(instances[0].merchant == "Daily Transit")
        #expect(instances[0].isRecurring == false, "Generated instances should not be recurring templates")
    }
}
